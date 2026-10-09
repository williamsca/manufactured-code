# Price triple differences across HUD wind zones; licensed records stay on Rivanna.
main <- function() {
    if (!nzchar(Sys.getenv("SLURM_JOB_ID"))) stop("Run on Rivanna in Slurm.")
    library(DBI); library(duckdb); library(data.table); library(fixest)
    library(jsonlite); library(ggplot2)
    source("program/lib/corelogic-windzone.R")
    source("program/lib/corelogic-ddd.R")
    input <- Sys.getenv("CORELOGIC_BUILD"); out <- Sys.getenv("CORELOGIC_RESULTS")
    ref <- Sys.getenv("CORELOGIC_REFERENCE")
    if (any(!nzchar(c(input,out,ref)))) stop("Set CORELOGIC_BUILD, CORELOGIC_RESULTS, CORELOGIC_REFERENCE")
    if (fromJSON(file.path(input,"manifest.json"))$status != "complete" ||
        !isTRUE(fromJSON(file.path(input,"audit","verification.json"))$ok)) stop("Unverified build")
    if (dir.exists(out)) stop("Results already exist")
    dir.create(out, recursive = TRUE)
    write_json(list(status="running", build=input), file.path(out,"manifest.json"))
    threads <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK","8")); setFixest_nthreads(threads)
    con <- dbConnect(duckdb()); on.exit(dbDisconnect(con, shutdown=TRUE), add=TRUE)
    dbExecute(con, sprintf("SET threads=%d",threads)); dbExecute(con,"SET memory_limit='16GB'")
    quote_path <- function(p) paste0("'",gsub("'","''",p,fixed=TRUE),"'")
    geo_file <- file.path(ref,"geo_county.parquet")
    geo <- as.data.table(dbGetQuery(con,paste("SELECT countyfp,statefp,name FROM read_parquet(",quote_path(geo_file),")")))
    wz <- cl_windzone_counties(geo)
    fwrite(wz,file.path(out,"windzone_crosswalk.csv"))
    legacy <- fread(file.path(ref,"ecfr-windzone.csv"), colClasses=c(countyfp="character"))
    audit <- merge(wz,legacy,by="countyfp",all=TRUE,suffixes=c("_reconstructed","_legacy"))
    fwrite(audit[is.na(wind_zone_legacy) | is.na(wind_zone_reconstructed) |
        wind_zone_legacy != wind_zone_reconstructed],file.path(out,"windzone_reconciliation.csv"))
    glob <- quote_path(file.path(input,"sales","*.parquet"))
    d <- as.data.table(dbGetQuery(con,paste("SELECT countyfp, mh, year_constr, year_sale,
        sale_price_2000, eligible_sale, consideration_documented, pb_sqft, pb_lot_sqft,
        wind_zone AS wind_zone_build FROM read_parquet(",glob,") WHERE eligible_sale AND countyfp IS NOT NULL
        AND date_sale >= MAKE_DATE(year_constr,1,1)")))
    d <- merge(d,wz[,.(countyfp,wind_zone,statefp)],by="countyfp",all.x=TRUE,sort=FALSE)
    fwrite(d[is.na(wind_zone),.(sales=.N),by=.(countyfp,mh)],file.path(out,"unmatched_counties.csv"))
    fwrite(d[,.(sales=.N),by=.(wind_zone_build,wind_zone,mh)],file.path(out,"zone_join_audit.csv"))
    d <- d[!is.na(wind_zone)]
    stopifnot(all(d$sale_price_2000>0),!anyNA(d$sale_price_2000))
    d[, `:=`(log_price=log(sale_price_2000), post_mh=mh * as.integer(year_constr>=1995),
        mh_tr=mh * (wind_zone>=2), mh_z2=mh*(wind_zone==2), mh_z3=mh*(wind_zone==3),
        mh_1994=mh * (year_constr==1994),
        sizes_ok=pb_sqft>=200 & pb_sqft<=10000 & pb_lot_sqft>=100 & pb_lot_sqft<=4356000)]
    d[is.na(sizes_ok),sizes_ok:=FALSE]
    d[, `:=`(post_mh_tr=post_mh*(wind_zone>=2),post_mh_z2=post_mh*(wind_zone==2),
        post_mh_z3=post_mh*(wind_zone==3), mh_1994_tr=mh_1994*(wind_zone>=2),
        mh_1994_z2=mh_1994*(wind_zone==2),mh_1994_z3=mh_1994*(wind_zone==3),
        cohort_group=fifelse(year_constr==1994,"transition_1994",fifelse(year_constr>=1995,"post","pre")),
        log_sqft=log(pmax(pb_sqft,1)),log_lot=log(pmax(pb_lot_sqft,1)))]
    fwrite(d[,.(sales=.N,counties=uniqueN(countyfp),states=uniqueN(statefp)),
        by=.(wind_zone,mh,year_constr)],file.path(out,"support_by_vintage.csv"))
    fwrite(d[year_sale>=2000,.(sales=.N,counties=uniqueN(countyfp),states=uniqueN(statefp)),
        by=.(wind_zone,mh,cohort_group)],file.path(out,"support_post_2000.csv"))
    coefs <- list(); profiles <- list(); dids <- list(); models <- list(); support <- list(); unidentified <- list()
    collect <- function(m,id,param,cluster,dynamic) {
        tab <- as.data.table(coeftable(m),keep.rownames="term")
        setnames(tab,names(tab)[2:5],c("estimate","se","t","p"))
        ci <- confint(m)
        tab[, `:=`(ci_low=ci[term,1],ci_high=ci[term,2],specification=id,
            parameterization=param,cluster=cluster,n=nobs(m))]
        tab[, `:=`(pct=100*expm1(estimate),pct_low=100*expm1(ci_low),pct_high=100*expm1(ci_high))]
        if(dynamic) profiles[[paste(id,param,cluster)]] <<- tab else coefs[[paste(id,param,cluster)]] <<- tab
    }
    fit <- function(id,rows,controls="",county_type=TRUE,dynamic=FALSE) {
        x <- d[which(rows)]; cat("Estimating",id,"dynamic",dynamic,"N",nrow(x),"\n")
        if(!dynamic) {
            support[[id]] <<- x[,.(sales=.N,counties=uniqueN(countyfp),states=uniqueN(statefp)),
                by=.(wind_zone,mh,cohort_group)][,specification:=id]
            fwrite(rbindlist(support),file.path(out,"support_by_specification.csv"))
        }
        for(by_zone in c(FALSE,TRUE)) {
            param <- if(by_zone) "separate_zones" else "pooled_treated"
            f <- cl_ddd_formula(by_zone,dynamic,controls,county_type)
            m <- feols(f,x,vcov=~countyfp,mem.clean=TRUE)
            collect(m,id,param,"county",dynamic)
            if(dynamic) {
                modifiers <- if(by_zone) c("mh","mh_z2","mh_z3") else c("mh","mh_tr")
                expected <- setdiff(sort(unique(x$year_constr)),c(1992L,1993L))
                for(key in modifiers) {
                    terms <- names(coef(m))[grepl(paste0(":",key,"$"),names(coef(m)))]
                    observed <- as.integer(sub("year_constr::([0-9]+):.*","\\1",terms))
                    stopifnot(setequal(expected,observed),1994L %in% observed)
                }
            } else {
                # State clustering as a sensitivity check, including few-state support caveat.
                ms <- summary(m,vcov=~statefp)
                collect(ms,id,param,"state",FALSE)
                for(cl in c("county","state")) {
                    mm <- if(cl=="county") m else ms
                    b <- coef(mm); v <- vcov(mm); crit <- qt(.975,degrees_freedom(mm,"t"))
                    modifiers <- if(by_zone) c("", "post_mh_z2","post_mh_z3") else c("","post_mh_tr")
                    names(modifiers) <- if(by_zone) c("I","II","III") else c("I","II_III")
                    for(z in names(modifiers)) {
                        terms <- c("post_mh",modifiers[[z]]); terms <- terms[nzchar(terms)]
                        missing <- setdiff(terms,names(b))
                        if(length(missing)) {
                            unidentified[[paste(id,param,cl,z)]] <<- data.table(specification=id,
                                parameterization=param,cluster=cl,zone=z,missing_terms=paste(missing,collapse=";"))
                            dids[[paste(id,param,cl,z)]] <<- data.table(specification=id,
                                parameterization=param,cluster=cl,zone=z,estimate=NA_real_,se=NA_real_,
                                ci_low=NA_real_,ci_high=NA_real_,n=nobs(mm))
                            next
                        }
                        estimate <- sum(b[terms]); se <- sqrt(sum(v[terms,terms,drop=FALSE]))
                        dids[[paste(id,param,cl,z)]] <<- data.table(specification=id,
                            parameterization=param,cluster=cl,zone=z,estimate=estimate,se=se,
                            ci_low=estimate-crit*se,ci_high=estimate+crit*se,n=nobs(mm))
                    }
                }
            }
            models[[paste(id,param,dynamic)]] <<- summary(m,lean=TRUE)
            rm(m); gc()
        }
        if(length(coefs)) fwrite(rbindlist(coefs),file.path(out,"post_ddd_coefficients.csv"))
        if(length(profiles)) fwrite(rbindlist(profiles),file.path(out,"vintage_ddd_coefficients.csv"))
        if(length(dids)) fwrite(rbindlist(dids),file.path(out,"zone_did_coefficients.csv"))
        if(length(unidentified)) fwrite(rbindlist(unidentified),file.path(out,"unidentified_contrasts.csv"))
    }
    later <- d$year_sale>=2000
    size <- later & d$sizes_ok
    controls <- "+ log_sqft + I(log_sqft^2) + log_lot + I(log_lot^2)"
    fit("all_sales",rep(TRUE,nrow(d)))
    fit("sales_2000",later)
    fit("size_sample_2000",size)
    fit("size_controls_2000",size,controls)
    fit("no_florida_2000",later & d$statefp!="12")
    fit("strict_2000",later & d$consideration_documented)
    fit("common_type_intercept_2000",later,county_type=FALSE)
    fit("narrow_2000",later & d$year_constr>=1990 & d$year_constr<=1997)
    fit("sales_2000",later,dynamic=TRUE)
    fit("size_sample_2000",size,dynamic=TRUE)
    fit("size_controls_2000",size,controls,dynamic=TRUE)
    saveRDS(models,file.path(out,"models-private.rds"))
    source("program/estimate/plot-corelogic-windzone.R"); cl_plot_windzone(out)
    files <- c("program/lib/corelogic-windzone.R","program/lib/corelogic-ddd.R",
        "program/estimate/estimate-corelogic-windzone.R","program/estimate/plot-corelogic-windzone.R",geo_file)
    dir.create(file.path(out,"source")); file.copy(files[1:4],file.path(out,"source"))
    write_json(list(status="complete",build=input,job=Sys.getenv("SLURM_JOB_ID"),
        matched_preferred_sales=nrow(d),crosswalk_counties=nrow(wz),
        vintage_1994="Retained as own annual coefficient; static DDD has separate 1994 x MH x zone terms",
        wind_zone_source="24 CFR 3280.305(c)(2), official 2020 list, matched to geo_county v2026-09-02 incl. historical counties",
        zone_II_counties=144,zone_III_counties=25,zone_III_fips_codes=sum(wz$wind_zone==3),
        lower_order_terms="county x sale year; county x type (or type x zone sensitivity); zone x annual vintage",
        code_reference_md5=as.list(tools::md5sum(files)),session=capture.output(sessionInfo())),
        file.path(out,"manifest.json"),pretty=TRUE,auto_unbox=TRUE)
    cat("COMPLETE",out,"\n")
}
if(sys.nframe()==0L) main()
