# Aggregate-only figures, using the project's academic economics style.
cl_plot_windzone <- function(out) {
    library(data.table); library(ggplot2)
    d <- fread(file.path(out,"vintage_ddd_coefficients.csv"))
    d <- d[grepl("^year_constr::",term) & !grepl(":mh$",term)]
    d[, `:=`(vintage=as.integer(sub("year_constr::([0-9]+):.*","\\1",term)),
        contrast=sub(".*:","",term))]
    draw <- function(sample_ids,labels,by_zone,filename) {
        x <- d[specification %in% sample_ids & parameterization ==
            if(by_zone) "separate_zones" else "pooled_treated"]
        refs <- CJ(specification=sample_ids,vintage=c(1992L,1993L),
            contrast=if(by_zone) c("mh_z2","mh_z3") else "mh_tr")
        refs[, `:=`(pct=0,pct_low=0,pct_high=0)]
        x <- rbind(x,refs,fill=TRUE)
        x[, series:=factor(specification,levels=sample_ids,labels=labels)]
        x[, comparison:=factor(contrast,levels=c("mh_tr","mh_z2","mh_z3"),
            labels=c("Zones II/III minus zone I","Zone II minus zone I","Zone III minus zone I"))]
        p <- ggplot(x,aes(vintage,pct,color=series,shape=series)) +
            annotate("rect",xmin=1993.5,xmax=1994.5,ymin=-Inf,ymax=Inf,fill="gray80",alpha=.4) +
            geom_hline(yintercept=0,linetype="dashed",color="gray") +
            geom_vline(xintercept=1993.5,linetype="dotted",color="black") +
            geom_errorbar(aes(ymin=pct_low,ymax=pct_high),width=.15,position=position_dodge(.25)) +
            geom_point(size=2,position=position_dodge(.25)) +
            scale_color_manual(values=c("#0072B2","#D55E00")) + scale_shape_manual(values=c(16,17)) +
            scale_x_continuous(breaks=1984:1999) +
            labs(x="Original construction year",y="Triple difference in MH prices (%)",
                color=NULL,shape=NULL,caption="Sales 2000-2023; joint 1992-1993 reference. Shaded 1994 cohort partially treated; 95% intervals clustered by county.") +
            theme_classic(base_size=14) + theme(text=element_text(family="serif"),
                legend.position="bottom",legend.text=element_text(size=12),
                plot.caption=element_text(size=10))
        if(by_zone) p <- p + facet_wrap(~comparison,ncol=1)
        ggsave(file.path(out,paste0(filename,".pdf")),p,width=9,height=if(by_zone) 7 else 5)
        ggsave(file.path(out,paste0(filename,".png")),p,width=9,height=if(by_zone) 7 else 5,dpi=150)
    }
    draw(c("sales_2000"),"All qualifying sales",FALSE,"vintage_ddd")
    draw(c("size_sample_2000","size_controls_2000"),
        c("Common sample, no size controls","Floor area and lot size controls"),FALSE,"vintage_ddd_size")
    draw(c("size_sample_2000","size_controls_2000"),
        c("Common sample, no size controls","Floor area and lot size controls"),TRUE,"vintage_ddd_byzone")
}
