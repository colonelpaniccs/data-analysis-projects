#------------------------------------
# Data 401
# Julian Johnson
# Final Project - Food & ACEs in Philly
#------------------------------------
library(tidyverse)
library(shinythemes)
library(shiny)
library(plyr)
library(leaflet)
library(dplyr)
library(survey)
library(sf)
library(readr)
library(stargazer)
library(rsconnect)
library(shinyjs)

#------------------------------------
# Data Duties - cleaning it up
#------------------------------------
#setwd("~/Library/CloudStorage/Dropbox/DATA401/Week 8")

place <- read.csv("place_data.csv")
food <- read.csv("free_meal_sites.csv")
zips <- st_read("Zipcodes_Poly")

food <- food[!is.na(food$category_type), ]
food <- food %>%
  filter(category_type != "")

unique(food$category_type)

#make icons
icon <- iconList(
  "Senior Meal Site" = makeIcon(iconUrl = "icons/seniormeal.png", iconWidth = 50, iconHeight = 50),
  "Food Site" = makeIcon(iconUrl = "icons/foodsite.png", iconWidth = 50, iconHeight = 50),
  "General Meal Site" = makeIcon(iconUrl = "icons/genmeal.png", iconWidth = 50, iconHeight = 50),
  "Public Benefits" = makeIcon(iconUrl = "icons/services.png", iconWidth = 50, iconHeight = 50)
)

icon_uri <- function(path) paste0("data:image/png;base64,", base64enc::base64encode(path))

icon_legend_html <- paste0(
  "<div style='background: white; padding: 8px 10px; border-radius: 4px; box-shadow: 0 1px 4px rgba(0,0,0,0.4); font-size: 13px; line-height: 22px;'>",
  "<strong>Food Sites</strong><br>",
  "<img src='", icon_uri("icons/foodsite.png"), "' width='18' height='18'> Food Site<br>",
  "<img src='", icon_uri("icons/genmeal.png"), "' width='18' height='18'> General Meal Site<br>",
  "<img src='", icon_uri("icons/seniormeal.png"), "' width='18' height='18'> Senior Meal Site<br>",
  "<img src='", icon_uri("icons/services.png"), "' width='18' height='18'> Public Benefits",
  "</div>"
)

place <- place %>%
  mutate(food_site_present = ifelse(CODE %in% food$zip_code, 1, 0))

#the ol' merge
map_date <- merge(zips, place, by = "CODE", all.x = TRUE)

map_date <- map_date %>%
  mutate(
    risk_category = cut(
      Risk, 
      breaks = c(0, 24, 49, 74, 100),
      labels = c("0-24%", "24-49%", "50-74%", "75-100%"),  
      right = TRUE, 
      include.lowest = TRUE  
    )
  )

#------------------------------------
# UI
#------------------------------------

ui <- fluidPage(
  useShinyjs(), 
  
  theme = shinytheme("flatly"),
  
  titlePanel("Food & ACEs in Philly"),
  
  navbarPage(
    id = "navbar", 
    
    tags$head(
      tags$script(HTML(
        "$(document).ready(function() {
          var homeIcon = $('<li id=\"home_button_li\"><a href=\"#\" id=\"home_button\"><svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" width=\"22\" height=\"22\" fill=\"white\"><path d=\"M12 3L2 12h3v8h5v-6h4v6h5v-8h3z\"/></svg></a></li>');
          $('.nav.navbar-nav').append(homeIcon);
          $('#home_button').on('click', function(e) {
            e.preventDefault();
            $('#navbar a[data-value=\"home\"]').tab('show');
          });
        });"
      )),
      tags$style(HTML("
        .navbar li a[data-value='home'],
        .navbar li.active a[data-value='home'],
        .navbar li a[data-value='home']:hover,
        .navbar li a[data-value='home']:focus,
        #home_button_li a,
        #home_button_li a:hover,
        #home_button_li a:focus {
          background-color: transparent !important;
        }
        .navbar {
          position: relative;
        }
        .navbar-nav {
          display: flex;
          align-items: stretch;
        }
        .navbar-nav > li {
          display: flex;
        }
        .navbar-nav > li > a {
          display: flex;
          align-items: center;
        }
        #home_button_li {
          position: absolute;
          top: 50%;
          right: 20px;
          transform: translateY(-50%);
          list-style: none;
        }
      "))
    ),

    #tab1 startpage with photo of campus...
    tabPanel(
      title = tags$img(src = icon_uri("icons/upenn_crest.png"), height = "30px", style = "vertical-align: middle;"),
      value = "home",
      tags$style(HTML("
        .background {
          background-image: url('https://collegevine.imgix.net/07f533c6-405e-43ee-ae0c-57784674a61e.jpg?fit=crop&crop=edges&auto=format&w=3275');
          background-size: cover;
          background-position: center;
          height: 100vh;
          color: white;
          text-align: center;
          padding: 100px;
        }
      ")),
      div(class = "background",
      )
    ),
    
    #tab2 welcome
    tabPanel(
      "Welcome",
      fluidRow(
        column(12,
               h2("Philadelphia Free Food Access Sites and Adverse Childhood Events"),
               p("The Philadelphia Free Food and Meal Sites dataset comes from a partnership of The City of Philadelphia's Office of Children and Families (OCF) and local foodbanks. The partnership aimed to find locations providing free meals or free food in the city. The data includes site information such as location, hours, and any rules related to service."),
               p("The following food site definitions were taken from the Food and Meal Finder dataset"),
               tags$ul(
                 tags$li(tags$strong("Food Sites:"), " Any resident is eligible - supplemental food and groceries"),
                 tags$li(tags$strong("General Meal Sites:"), " Any resident is eligible - offer ready-to-eat meals"),
                 tags$li(tags$strong("Older and Adult Meal Sites:"), " Age of eligibility varies by site - Spouses of eligible adults may also receive meals at these sites. These sites offer ready-to-eat meals"),
                 tags$li(tags$strong("Food Assistance and Benefits:"), " Eligibility varies by site - Learn about and enroll in public benefits, get nutrition services and support, and get referrals to health care or social services.")
               ),
               p("Combining this data with the Risk Index of children within Philadelphia, I look to explore the relation of food availability (specifically free food) in the areas where it is needed most."),
               p("This data could be used as a resource to understand the impact of food sites on children in communities. With my analysis being limited by my ability, others may find this a useful stepping stone in uncovering substantiated insights."),
        ),
        p(tags$strong("Considerations:"), "Hours of operation was not taken into account in my analysis. Senior and adult food sites were kept in the data as many children are living with grandparents or adult caretakers across the country."),
        
        
        p(tags$strong("Sources:"), 
          tags$a(href = "https://opendataphilly.org/datasets/free-food-sites/", 
                 target = "_blank", 
                 "https://opendataphilly.org/datasets/free-food-sites/"),
          ", ",
          tags$a(href = "https://www.scattergoodfoundation.org/think/publications/place-matters/", 
                 target = "_blank", 
                 "https://www.scattergoodfoundation.org/think/publications/place-matters/")
        )
      )
    ),
    
    #tab3 map
    tabPanel(
      "Risk Index Map ",
      fluidRow(
        column(12,
               p("Click a ZIP code to see its Risk Index, Poverty, Education, Unemployment, Crime, and ACEs breakdown."),
               leafletOutput("food_map", height = 600)
        )
      )
    ),
    
    #tab4 zip code comparison charts
    tabPanel(
      "ZIP Code Comparison",
      sidebarLayout(
        sidebarPanel(
          selectInput(
            "interest_zip",
            label = "Zip Code of Interest",
            choices = as.character(unique(map_date$CODE)),
            selected = as.character(unique(map_date$CODE))[1]
          ),
          selectInput(
            "benchmark_zip",
            label = "Benchmark Zip Code",
            choices = c("City Average", as.character(unique(map_date$CODE)))
          )
        ),
        mainPanel(
          fluidRow(
            column(12, tags$div(
              style = "display: flex; align-items: center; gap: 24px; margin-bottom: 15px; padding: 8px 12px; background-color: #F5F5F5; border-radius: 4px;",
              tags$div(style = "display: flex; align-items: center; gap: 8px;",
                       tags$span(style = "display: inline-block; width: 14px; height: 14px; background-color: #7D7098; border-radius: 2px;"),
                       tags$span("Selected ZIP")),
              tags$div(style = "display: flex; align-items: center; gap: 8px;",
                       tags$span(style = "display: inline-block; width: 14px; height: 14px; background-color: #779870; border-radius: 2px;"),
                       tags$span("Benchmark"))
            ))
          ),
          fluidRow(
            column(4, div(
              style = "border: 2px solid #B0C4DE; padding: 10px;",
              tags$h4(style = "background-color: #D3D3D3; padding: 5px;", "Risk"),
              plotOutput("barplot_Risk", height = "400px")
            )),
            column(4, div(
              style = "border: 2px solid #B0C4DE; padding: 10px;",
              tags$h4(style = "background-color: #D3D3D3; padding: 5px;", "Poverty"),
              plotOutput("barplot_Poverty", height = "400px")
            )),
            column(4, div(
              style = "border: 2px solid #B0C4DE; padding: 10px;",
              tags$h4(style = "background-color: #D3D3D3; padding: 5px;", "Education"),
              plotOutput("barplot_Education", height = "400px")
            ))
          ),
          fluidRow(
            column(4, div(
              style = "border: 2px solid #B0C4DE; padding: 10px;",
              tags$h4(style = "background-color: #D3D3D3; padding: 5px;", "Unemployment"),
              plotOutput("barplot_Unemployment", height = "400px")
            )),
            column(4, div(
              style = "border: 2px solid #B0C4DE; padding: 10px;",
              tags$h4(style = "background-color: #D3D3D3; padding: 5px;", "Crime"),
              plotOutput("barplot_Crime", height = "400px")
            )),
            column(4, div(
              style = "border: 2px solid #B0C4DE; padding: 10px;",
              tags$h4(style = "background-color: #D3D3D3; padding: 5px;", "ACEs"),
              plotOutput("barplot_ACEs", height = "400px")
            ))
          ),
          fluidRow(
            column(12, tags$br(),
                   tags$strong("Risk:"),
                   tags$span("A composite index of measures of poverty, education, unemployment, crime and ACEs")),
            column(12, tags$strong("Poverty:"), tags$span("Percent of families with children below the poverty level")),
            column(12, tags$strong("Education:"), tags$span("Percent with less than 9th grade education")),
            column(12, tags$strong("Unemployment:"), tags$span("Percent of unemployed")),
            column(12, tags$strong("Crime:"), tags$span("Shooting victims per 10,000")),
            column(12, tags$strong("ACEs:"), tags$span("Percent with at least one Adverse Childhood Experience"))
          )
        )
      )
    ),

    #tab5 this is where the regression will live
    tabPanel(
      "Food Availability & ACEs - Risk Predictor",
      fluidRow(
        column(12,
               h3("Food Site Access and ACEs Risk Regression"),
               p("This regression tests whether the presence of a free food distribution site in a ZIP code relates to its Risk Index."),
               br(),
               uiOutput("regTab"),
               br(),
               p("Food Site Access is a binary indicator marking whether a ZIP code has any type of free food distribution site (1 for yes, 0 for no). Because these results are observational, a coefficient shows association, not causation - food sites tend to be located in areas where they are needed most, so we can't conclude that access itself drives Risk up or down. Further exploration into site type, site count, hours of operation, and true access would strengthen this analysis.")
        )
      )
    )
  )
)

#------------------------------------
# Server
#------------------------------------

server <- function(input, output, session) {

  food_model <- lm(Risk ~ food_site_present, data = place)

  output$regTab <- renderUI({
    tbl <- capture.output(
      stargazer(food_model, type = "html",
                dep.var.labels = "Risk Index",
                covariate.labels = "Food Site Access")
    )
    HTML(paste(tbl, collapse = "\n"))
  })

  zipselect <- reactive({
    req(input$interest_zip)
    map_date %>% filter(as.character(CODE) == input$interest_zip)
  })

  selected_benchmark_zip <- reactive({
    req(input$benchmark_zip)
    if (input$benchmark_zip == "City Average") {
      map_date %>%
        summarize(
          Risk = mean(Risk, na.rm = TRUE),
          Poverty = mean(Poverty, na.rm = TRUE),
          Education = mean(Education, na.rm = TRUE),
          Unemployment = mean(Unemployment, na.rm = TRUE),
          Crime = mean(Crime, na.rm = TRUE),
          ACEs = mean(ACEs, na.rm = TRUE)
        )
    } else {
      map_date %>% filter(as.character(CODE) == input$benchmark_zip)
    }
  })

  create_bar_plot <- function(factor_name, zip_value, benchmark_value, zip_label, benchmark_label) {
    if (is.na(zip_value) && is.na(benchmark_value)) {
      return(
        ggplot() +
          annotate("text", x = 0, y = 0, label = "No data available for this comparison", size = 5, color = "gray40") +
          theme_void() +
          labs(title = paste(factor_name, "Compares"))
      )
    }

    zip_label <- if (is.na(zip_value)) paste0(zip_label, " (no data)") else zip_label
    benchmark_label <- if (is.na(benchmark_value)) paste0(benchmark_label, " (no data)") else benchmark_label
    zip_value <- ifelse(is.na(zip_value), 0, zip_value)
    benchmark_value <- ifelse(is.na(benchmark_value), 0, benchmark_value)

    data <- data.frame(
      Role = factor(c("Selected ZIP", "Benchmark"), levels = c("Selected ZIP", "Benchmark")),
      Value = c(zip_value, benchmark_value)
    )

    ggplot(data, aes(x = Role, y = Value, fill = Role)) +
      geom_bar(stat = "identity", position = "dodge", show.legend = FALSE) +
      scale_x_discrete(labels = c(zip_label, benchmark_label)) +
      labs(title = paste(factor_name, "Compares"), x = NULL) +
      scale_fill_manual(values = c("Selected ZIP" = "#7D7098", "Benchmark" = "#779870")) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.major = element_line(colour = "gray", linewidth = 0.5),
        panel.grid.minor = element_line(colour = "gray", linewidth = 0.25),
        panel.grid = element_line(color = "gray")
      ) +
      ylab("Percentage")
  }

  output$barplot_Risk <- renderPlot({
    create_bar_plot("Risk", zipselect()$Risk, selected_benchmark_zip()$Risk, input$interest_zip, input$benchmark_zip)
  })

  output$barplot_Poverty <- renderPlot({
    create_bar_plot("Poverty", zipselect()$Poverty, selected_benchmark_zip()$Poverty, input$interest_zip, input$benchmark_zip)
  })

  output$barplot_Education <- renderPlot({
    create_bar_plot("Education", zipselect()$Education, selected_benchmark_zip()$Education, input$interest_zip, input$benchmark_zip)
  })

  output$barplot_Unemployment <- renderPlot({
    create_bar_plot("Unemployment", zipselect()$Unemployment, selected_benchmark_zip()$Unemployment, input$interest_zip, input$benchmark_zip)
  })

  output$barplot_Crime <- renderPlot({
    create_bar_plot("Crime", zipselect()$Crime, selected_benchmark_zip()$Crime, input$interest_zip, input$benchmark_zip)
  })

  output$barplot_ACEs <- renderPlot({
    create_bar_plot("ACEs", zipselect()$ACEs, selected_benchmark_zip()$ACEs, input$interest_zip, input$benchmark_zip)
  })

  #map map baby
  output$food_map <- renderLeaflet({
    leaflet(map_date) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addPolygons(
        fillColor = ~colorFactor("YlOrRd", domain = map_date$risk_category)(risk_category), 
        color = "white",  
        weight = 1, 
        opacity = 1, 
        fillOpacity = 0.7,  
        popup = ~paste0(
          "<strong>Zip Code:</strong>", CODE, "<br>","<br>",
          "<strong>Risk Index:</strong> ", Risk, "%<br>",
          "<strong>Poverty:</strong> ", Poverty, "%<br>",
          "<strong>Education:</strong> ", Education, "%<br>",
          "<strong>Unemployment:</strong> ", Unemployment, "%<br>",
          "<strong>Crime Rate:</strong> ", Crime, "<br>",
          "<strong>ACEs:</strong> ", ACEs
        )
      ) %>%
      addLegend(
        pal = colorFactor("YlOrRd", domain = map_date$risk_category),
        values = ~risk_category,
        title = "<strong>Risk: Lowest to Highest </strong>",
        position = "bottomright",
        opacity = 1
      ) %>%
      addMarkers(
        ~food$x, ~food$y,
        icon = ~icon[food$category_type],
        popup = ~food$category_type
      ) %>%
      addControl(html = icon_legend_html, position = "bottomleft")
  })
  
}

# Run the app
shinyApp(ui = ui, server = server)

