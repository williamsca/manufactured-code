---
title: The Returns to Climate Adaptation in Manufactured Housing
author:
- name: Colin Williams
  affiliation: University of Virginia
  email: chv7bg@virginia.edu
date: \today
abstract: 
header-includes:
- \usepackage{lscape}
...

# Introduction

# Tables and Figures


\begin{table}
\input{output/descriptives/sumstats-nfip.tex}
\end{table}

\begin{figure}[htbp]
  \centering
  \caption{Effect of Post-1994 HUD Standards on Net Building Payment per Claim}\label{fig:es-net-building-pmt}
  \includegraphics[width=\textwidth]{output/event-study/es-net-building-pmt.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Coefficients from a claim-level regression of net building payment on interactions between construction period and a manufactured housing indicator, relative to the 1991 bin. Dotted vertical line marks 1994, the year HUD wind standards took effect. Regressions include tract $\times$ loss-period and MH fixed effects. 95\% confidence intervals shown.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{figure}[htbp]
  \centering
  \caption{Effect of Post-1994 HUD Standards on Net Contents Payment per Claim}\label{fig:es-net-contents-pmt}
  \includegraphics[width=\textwidth]{output/event-study/es-net-contents-pmt.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: See Figure \ref{fig:es-net-building-pmt}. Outcome is net contents payment per claim.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{figure}[htbp]
  \centering
  \caption{Effect of Post-1994 HUD Standards on Claim Rate}\label{fig:es-claim-rate}
  \includegraphics[width=\textwidth]{output/event-study/es-claim-rate.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Coefficients from a cell-level regression of claims per policy on interactions between construction period and a manufactured housing indicator, relative to the 1991 bin. Weighted by claims. Regressions include county $\times$ loss-period and MH fixed effects. 95\% confidence intervals shown.
  \end{footnotesize}
  \end{flushleft}
\end{figure}
