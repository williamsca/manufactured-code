# Descriptive plots: NFIP claims, policies, and payments by construction year
# Outputs: figures/nfip-claims-by-vintage.pdf
#          figures/nfip-policies-by-vintage.pdf
#          figures/nfip-pmt-by-vintage.pdf

rm(list = ls())
library(here)
library(data.table)
library(ggplot2)

v_palette <- c("#0072B2", "#D55E00")
v_shapes  <- c(16, 17)
v_lines   <- c("solid", "dashed")

theme_paper <- function(base_size = 14) {
  theme_classic(base_size = base_size) +
    theme(
      text = element_text(family = "serif"),
      legend.position = "right"
    )
}

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, housing_type := fifelse(mh == 1, "Manufactured", "Site-built")]

# aggregate to construction year × housing type ----
dt_agg <- dt[,
    .(claims_n    = sum(claims_n,    na.rm = TRUE),
      policies_n  = sum(policies_n,  na.rm = TRUE),
      net_building_pmt_tot = sum(net_building_pmt_tot, na.rm = TRUE)),
    by = .(year_constr, housing_type)
]

# index claims and policies to 1993 = 1
base1993 <- dt_agg[year_constr == 1993, .(housing_type, claims_base = claims_n, policies_base = policies_n)]
dt_agg <- base1993[dt_agg, on = "housing_type"]
dt_agg[, claims_idx   := claims_n   / claims_base]
dt_agg[, policies_idx := policies_n / policies_base]

# average payment per claim by construction year × housing type × treated status ----
dt_agg_tr <- dt[,
    .(claims_n         = sum(claims_n,            na.rm = TRUE),
      policies_n        = sum(policies_n,           na.rm = TRUE),
      net_building_pmt_tot = sum(net_building_pmt_tot, na.rm = TRUE)),
    by = .(year_constr, housing_type, treated)
]
dt_agg_tr[, net_building_pmt_pclaim := fifelse(
    claims_n > 0, net_building_pmt_tot / claims_n, NA_real_)]
dt_agg_tr[, claim_rate := fifelse(
    policies_n > 0, claims_n / policies_n, NA_real_)]
dt_agg_tr[, series := paste0(housing_type, " (", fifelse(treated, "treated", "untreated"), ")")]

# (1) claims by construction year (indexed to 1993 = 1) ----
p_claims <- ggplot(
    dt_agg, aes(x = year_constr, y = claims_idx,
                color = housing_type, shape = housing_type,
                linetype = housing_type)) +
  geom_line() +
  geom_point(size = 2) +
  geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
  scale_color_manual(values = v_palette, name = NULL) +
  scale_shape_manual(values = v_shapes, name = NULL) +
  scale_linetype_manual(values = v_lines, name = NULL) +
  labs(x = "Construction year", y = "Claims (1993 = 1)") +
  theme_paper()
p_claims

ggsave(here("output", "descriptives", "nfip-claims-by-vintage.pdf"),
       p_claims, width = 9, height = 5)

# (2) policies by construction year (indexed to 1993 = 1) ----
p_policies <- ggplot(
    dt_agg[!is.na(policies_idx)],
    aes(x = year_constr, y = policies_idx,
        color = housing_type, shape = housing_type,
        linetype = housing_type)) +
  geom_line() +
  geom_point(size = 2) +
  geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
  scale_color_manual(values = v_palette, name = NULL) +
  scale_shape_manual(values = v_shapes, name = NULL) +
  scale_linetype_manual(values = v_lines, name = NULL) +
  labs(x = "Construction year", y = "Policies (1993 = 1)") +
  theme_paper()

p_policies

ggsave(here("output", "descriptives", "nfip-policies-by-vintage.pdf"),
       p_policies, width = 9, height = 5)

# (3) average building payment per claim by construction year × treated status ----
v_palette4 <- c("#0072B2", "#56B4E9", "#D55E00", "#E69F00")
v_shapes4  <- c(16, 1, 17, 2)
v_lines4   <- c("solid", "dashed", "solid", "dashed")

series_levels <- c("Manufactured (treated)", "Manufactured (untreated)",
                   "Site-built (treated)",   "Site-built (untreated)")
dt_agg_tr[, series := factor(series, levels = series_levels)]

p_pmt <- ggplot(
    dt_agg_tr[!is.na(net_building_pmt_pclaim)],
    aes(x = year_constr, y = net_building_pmt_pclaim / 1e3,
        color = series, shape = series, linetype = series)) +
  geom_line() +
  geom_point(size = 2) +
  geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
  scale_color_manual(values = v_palette4, name = NULL) +
  scale_shape_manual(values = v_shapes4, name = NULL) +
  scale_linetype_manual(values = v_lines4, name = NULL) +
  labs(x = "Construction year", y = "Avg. building payment per claim (000s)") +
  theme_paper()

p_pmt

ggsave(here("output", "descriptives", "nfip-pmt-by-vintage.pdf"),
       p_pmt, width = 9, height = 5)

# (4) claim rate by construction year × housing type × treated status ----
p_claimrate <- ggplot(
    dt_agg_tr[!is.na(claim_rate)],
    aes(x = year_constr, y = claim_rate,
        color = series, shape = series, linetype = series)) +
  geom_line() +
  geom_point(size = 2) +
  geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
  scale_color_manual(values = v_palette4, name = NULL) +
  scale_shape_manual(values = v_shapes4, name = NULL) +
  scale_linetype_manual(values = v_lines4, name = NULL) +
  labs(x = "Construction year", y = "Claims per policy") +
  theme_paper()

p_claimrate

ggsave(here("output", "descriptives", "nfip-claimrate-by-vintage.pdf"),
       p_claimrate, width = 9, height = 5)
