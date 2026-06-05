# =============================================================================
# IRT Psychometric Dashboard — PISA 2022
# app/app.R
# Author: Washington Casamen Nolasco
# =============================================================================

library(shiny)
library(mirt)
library(dplyr)
library(ggplot2)
library(tidyr)

helper_candidates <- file.path(c(".", ".."), "src", "irt_functions.R")
helper_path <- helper_candidates[file.exists(helper_candidates)][1]

if (is.na(helper_path)) {
  stop("Could not find src/irt_functions.R. Run the app from the repo root or app/.", call. = FALSE)
}

source(helper_path)

# -----------------------------------------------------------------------------
# Load cached objects and shared derived data
# -----------------------------------------------------------------------------

project_root <- find_project_root()
cached_objects <- load_cached_irt_objects(project_root)

model_1pl <- cached_objects$model_1pl
model_2pl <- cached_objects$model_2pl
dif_df    <- cached_objects$dif_df

params_2pl <- extract_2pl_parameters(model_2pl, dif_df)
item_names  <- params_2pl$item
theta_seq   <- seq(-4, 4, length.out = 300)
tif_data    <- build_tif_data(params_2pl, theta_seq)

# -----------------------------------------------------------------------------
# UI
# -----------------------------------------------------------------------------

ui <- navbarPage(
  title = "IRT Psychometric Dashboard — PISA 2022",
  theme = bslib::bs_theme(bootswatch = "cosmo"),

  # ---------------------------------------------------------------------------
  # Tab 1: Model Comparison
  # ---------------------------------------------------------------------------
  tabPanel(
    "Model Comparison",
    fluidPage(
      br(),
      fluidRow(
        column(12,
          h3("1PL vs 2PL Model Fit"),
          p("The 2PL model is selected based on AIC, BIC, and Likelihood Ratio Test.
            The 3PL failed to converge — PISA items are largely constructed-response,
            making the pseudo-guessing parameter theoretically unjustified."),
          br()
        )
      ),
      fluidRow(
        column(4,
          wellPanel(
            h4("Fit Indices"),
            tableOutput("fit_table")
          )
        ),
        column(8,
          wellPanel(
            h4("Parameter Distribution — 2PL"),
            plotOutput("param_dist_plot", height = "350px")
          )
        )
      ),
      fluidRow(
        column(12,
          wellPanel(
            h4("Likelihood Ratio Test"),
            verbatimTextOutput("lrt_output")
          )
        )
      )
    )
  ),

  # ---------------------------------------------------------------------------
  # Tab 2: Item Browser
  # ---------------------------------------------------------------------------
  tabPanel(
    "Item Browser",
    fluidPage(
      br(),
      fluidRow(
        column(3,
          wellPanel(
            h4("Select Item"),
            selectInput("selected_item", "Item:",
                        choices  = item_names,
                        selected = item_names[1]),
            br(),
            h5("Item Parameters"),
            tableOutput("item_params_table"),
            br(),
            uiOutput("dif_badge")
          )
        ),
        column(9,
          wellPanel(
            h4("Item Characteristic Curve"),
            plotOutput("icc_plot", height = "350px")
          ),
          wellPanel(
            h4("Item Information Function"),
            plotOutput("iif_plot", height = "250px")
          )
        )
      )
    )
  ),

  # ---------------------------------------------------------------------------
  # Tab 3: Test Information Function
  # ---------------------------------------------------------------------------
  tabPanel(
    "Test Information",
    fluidPage(
      br(),
      fluidRow(
        column(3,
          wellPanel(
            h4("TIF Summary"),
            br(),
            tableOutput("tif_summary_table"),
            br(),
            h5("Explore θ point"),
            sliderInput("theta_point", "θ value:",
                        min = -4, max = 4, value = 0, step = 0.1),
            br(),
            h5("At selected θ:"),
            tableOutput("tif_point_table")
          )
        ),
        column(9,
          wellPanel(
            h4("Test Information Function with Standard Error"),
            p("Blue = Test Information (higher is better) | Red = SE(θ) (lower is better)"),
            plotOutput("tif_plot", height = "400px")
          )
        )
      )
    )
  ),

  # ---------------------------------------------------------------------------
  # Tab 4: DIF Explorer
  # ---------------------------------------------------------------------------
  tabPanel(
    "DIF Explorer",
    fluidPage(
      br(),
      fluidRow(
        column(12,
          h3("Differential Item Functioning — OECD vs Non-OECD"),
          p("Lord's χ² test on 2PL parameters (a, d). Adjusted p-values use Bonferroni correction.
            58 of 191 items (30.4%) show significant DIF at α = 0.05.")
        )
      ),
      br(),
      fluidRow(
        column(4,
          wellPanel(
            h4("Filter"),
            radioButtons("dif_filter", "Show:",
                         choices  = c("All items" = "all",
                                      "DIF only"  = "dif",
                                      "No DIF"    = "nodif"),
                         selected = "all"),
            br(),
            h4("Summary"),
            tableOutput("dif_summary_table")
          )
        ),
        column(8,
          wellPanel(
            h4("DIF Magnitude — Lord's χ²"),
            plotOutput("dif_plot", height = "500px")
          )
        )
      ),
      fluidRow(
        column(12,
          wellPanel(
            h4("Item-level DIF Results"),
            DT::dataTableOutput("dif_table")
          )
        )
      )
    )
  )
)

# -----------------------------------------------------------------------------
# Server
# -----------------------------------------------------------------------------

server <- function(input, output, session) {

  # --- Tab 1: Model Comparison ---

  output$fit_table <- renderTable({
    data.frame(
      Model = c("1PL (Rasch)", "2PL"),
      AIC   = round(c(model_1pl@Fit$AIC, model_2pl@Fit$AIC), 0),
      BIC   = round(c(model_1pl@Fit$BIC, model_2pl@Fit$BIC), 0)
    )
  }, striped = TRUE, hover = TRUE)

  output$param_dist_plot <- renderPlot({
    p1 <- ggplot(params_2pl, aes(x = a)) +
      geom_histogram(fill = "#2E86AB", color = "white", bins = 25) +
      geom_vline(xintercept = 0.5, linetype = "dashed", color = "#E84855") +
      labs(title = "Discrimination (a)", x = "a", y = "Count") +
      theme_minimal(base_size = 11)

    p2 <- ggplot(params_2pl, aes(x = b)) +
      geom_histogram(fill = "#2E86AB", color = "white", bins = 25) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
      labs(title = "Difficulty (b)", x = "b", y = "Count") +
      theme_minimal(base_size = 11)

    gridExtra::grid.arrange(p1, p2, ncol = 2)
  })

  output$lrt_output <- renderPrint({
    anova(model_1pl, model_2pl)
  })

  # --- Tab 2: Item Browser ---

  selected_params <- reactive({
    params_2pl[params_2pl$item == input$selected_item, ]
  })

  output$item_params_table <- renderTable({
    p <- selected_params()
    data.frame(
      Parameter = c("Discrimination (a)", "Difficulty (b)"),
      Value     = round(c(p$a, p$b), 3)
    )
  }, striped = FALSE, hover = FALSE, colnames = TRUE)

  output$dif_badge <- renderUI({
    p <- selected_params()
    if (!is.na(p$dif_flag) && p$dif_flag == "DIF") {
      div(
        style = "background-color:#E84855; color:white; padding:8px 12px;
                 border-radius:4px; text-align:center; font-weight:bold;",
        paste0("⚠ DIF Flagged — χ² = ", round(p$X2, 2),
               " | adj_p = ", formatC(p$adj_p, format = "e", digits = 2))
      )
    } else {
      div(
        style = "background-color:#2E86AB; color:white; padding:8px 12px;
                 border-radius:4px; text-align:center; font-weight:bold;",
        "✓ No DIF Detected"
      )
    }
  })

  output$icc_plot <- renderPlot({
    p   <- selected_params()
    df  <- data.frame(
      theta = theta_seq,
      prob  = icc_2pl(p$a, p$b, theta_seq)
    )
    color <- if (!is.na(p$dif_flag) && p$dif_flag == "DIF") "#E84855" else "#2E86AB"

    ggplot(df, aes(x = theta, y = prob)) +
      geom_line(color = color, linewidth = 1.2) +
      geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray50") +
      geom_vline(xintercept = p$b, linetype = "dotted", color = "gray60") +
      annotate("text", x = p$b + 0.15, y = 0.05,
               label = paste0("b = ", round(p$b, 2)), hjust = 0, size = 3.5) +
      labs(title    = paste("ICC —", input$selected_item),
           subtitle = paste0("a = ", round(p$a, 3), "  |  b = ", round(p$b, 3)),
           x = "Ability (θ)", y = "P(Correct)") +
      theme_minimal(base_size = 12) +
      ylim(0, 1)
  })

  output$iif_plot <- renderPlot({
    p  <- selected_params()
    df <- data.frame(
      theta = theta_seq,
      info  = iif_2pl(p$a, p$b, theta_seq)
    )
    color <- if (!is.na(p$dif_flag) && p$dif_flag == "DIF") "#E84855" else "#2E86AB"

    ggplot(df, aes(x = theta, y = info)) +
      geom_line(color = color, linewidth = 1.1) +
      geom_vline(xintercept = p$b, linetype = "dotted", color = "gray60") +
      labs(title = paste("IIF —", input$selected_item),
           x = "Ability (θ)", y = "Information I(θ)") +
      theme_minimal(base_size = 12)
  })

  # --- Tab 3: Test Information ---

  output$tif_summary_table <- renderTable({
    peak_theta <- tif_data$theta[which.max(tif_data$total_info)]
    peak_info  <- max(tif_data$total_info)
    peak_se    <- min(tif_data$se)
    good_range <- tif_data %>% filter(total_info >= peak_info * 0.5)

    data.frame(
      Metric = c("Peak θ", "Max Information", "Min SE",
                 "Effective range (>50% peak)"),
      Value  = c(round(peak_theta, 2),
                 round(peak_info, 2),
                 round(peak_se, 3),
                 paste0(round(min(good_range$theta), 2), " to ",
                        round(max(good_range$theta), 2)))
    )
  }, striped = TRUE)

  output$tif_point_table <- renderTable({
    closest <- tif_data[which.min(abs(tif_data$theta - input$theta_point)), ]
    data.frame(
      Metric = c("Information", "SE"),
      Value  = c(round(closest$total_info, 3), round(closest$se, 3))
    )
  })

  output$tif_plot <- renderPlot({
    scale_factor <- max(tif_data$total_info) / max(tif_data$se) * 0.3

    ggplot(tif_data, aes(x = theta)) +
      geom_line(aes(y = total_info), color = "#2E86AB", linewidth = 1.2) +
      geom_line(aes(y = se * scale_factor), color = "#E84855",
                linewidth = 0.9, linetype = "dashed") +
      geom_vline(xintercept = input$theta_point,
                 color = "gray40", linetype = "solid", linewidth = 0.7) +
      scale_y_continuous(
        name     = "Test Information",
        sec.axis = sec_axis(~ . / scale_factor, name = "Standard Error SE(θ)")
      ) +
      labs(x = "Ability (θ)",
           caption = "Blue = Test Information | Red dashed = SE(θ) | Vertical line = selected θ") +
      theme_minimal(base_size = 12)
  })

  # --- Tab 4: DIF Explorer ---

  filtered_dif <- reactive({
    if (input$dif_filter == "dif")    return(dif_df %>% filter(dif_flag == "DIF"))
    if (input$dif_filter == "nodif")  return(dif_df %>% filter(dif_flag == "No DIF"))
    return(dif_df)
  })

  output$dif_summary_table <- renderTable({
    data.frame(
      Group    = c("DIF items", "No DIF items", "DIF rate"),
      Value    = c(sum(dif_df$dif_flag == "DIF"),
                   sum(dif_df$dif_flag == "No DIF"),
                   paste0(round(mean(dif_df$dif_flag == "DIF") * 100, 1), "%"))
    )
  }, striped = TRUE)

  output$dif_plot <- renderPlot({
    df <- filtered_dif() %>% arrange(X2)

    ggplot(df, aes(x = reorder(item, X2), y = X2, fill = dif_flag)) +
      geom_col() +
      geom_hline(yintercept = qchisq(0.95, df = 2),
                 linetype = "dashed", color = "black", linewidth = 0.8) +
      scale_fill_manual(values = c("DIF" = "#E84855", "No DIF" = "#2E86AB")) +
      coord_flip() +
      labs(x = "Item", y = "χ² statistic", fill = "") +
      theme_minimal(base_size = 9)
  })

  output$dif_table <- DT::renderDataTable({
    filtered_dif() %>%
      select(item, X2, df, p, adj_p, dif_flag) %>%
      mutate(
        X2     = round(X2, 3),
        p      = formatC(p, format = "e", digits = 3),
        adj_p  = formatC(adj_p, format = "e", digits = 3)
      ) %>%
      arrange(desc(X2))
  }, options = list(pageLength = 15, scrollX = TRUE),
     rownames = FALSE)
}

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------

shinyApp(ui = ui, server = server)
