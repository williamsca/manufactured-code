# Plot only aggregated coefficients; still run this workstream on Rivanna.
cl_plot_prices <- function(out) {
    library(data.table); library(ggplot2)
    pdat <- fread(file.path(out, "vintage_coefficients.csv"))[grepl("^year_constr::", term)]
    pdat[, vintage := as.integer(sub("year_constr::([0-9]+):mh", "\\1", term))]
    draw <- function(selected, labels, filename) {
        plotdata <- pdat[specification %in% selected]
        plotdata <- rbind(plotdata, CJ(specification = selected, vintage = c(1992L,1993L))[
            , `:=`(pct = 0, pct_low = 0, pct_high = 0)], fill = TRUE)
        plotdata[, series := factor(specification, levels = selected, labels = labels)]
        p <- ggplot(plotdata, aes(vintage, pct, color = series, shape = series)) +
            annotate("rect",xmin=1993.5,xmax=1994.5,ymin=-Inf,ymax=Inf,fill="gray80",alpha=.4) +
            geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
            geom_vline(xintercept = 1993.5, linetype = "dotted") +
            geom_errorbar(aes(ymin = pct_low, ymax = pct_high), width = .15, position = position_dodge(.25)) +
            geom_point(size = 2, position = position_dodge(.25)) +
            scale_color_manual(values = c("#0072B2", "#D55E00")) + scale_shape_manual(values = c(16,17)) +
            scale_x_continuous(breaks = 1984:1999) +
            labs(x = "Original construction year", y = "Relative MH vintage price (%)",
                 color = NULL, shape = NULL,
                 caption = "Joint 1992-1993 reference; shaded 1994 cohort partially treated. County-clustered 95% intervals.") +
            theme_classic(base_size = 14) + theme(text = element_text(family = "serif"),
                legend.position = "bottom", legend.text = element_text(size = 12),
                plot.caption = element_text(size = 11))
        ggsave(file.path(out, paste0(filename, ".pdf")), p, width = 9, height = 5)
        ggsave(file.path(out, paste0(filename, ".png")), p, width = 9, height = 5, dpi = 150)
    }
    draw(c("pooled", "county_type_2000"),
         c("County x sale year; 1990-2023", "Also county x type; 2000-2023"), "vintage_prices")
    draw(c("size_sample_2000", "size_controls_2000"),
         c("Common sample, no size controls", "Floor area and lot size controls"), "vintage_prices_size")
}
if (sys.nframe() == 0L) {
    if (!nzchar(Sys.getenv("SLURM_JOB_ID"))) stop("Run on Rivanna in Slurm.")
    out <- Sys.getenv("CORELOGIC_RESULTS")
    if (!nzchar(out)) stop("Set CORELOGIC_RESULTS")
    cl_plot_prices(out)
    jsonlite::write_json(list(status = "complete", job = Sys.getenv("SLURM_JOB_ID"),
        code_md5 = unname(tools::md5sum("program/estimate/plot-corelogic-prices.R"))),
        file.path(out, "figure_manifest.json"), pretty = TRUE, auto_unbox = TRUE)
}
