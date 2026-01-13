// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Re-export the Stimulus application for engine controllers that import from "application"
export { application } from "controllers/application"

// Optional engines' import engine controllers (registers them with Stimulus)
// import "tudla_hubstaff/controllers/index"

import ApexCharts from "apexcharts"
window.ApexCharts = ApexCharts