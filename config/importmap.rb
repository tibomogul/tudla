# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "apexcharts", to: "apexcharts.esm.js"
pin "hillchart", to: "hillchart.js"
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@1.15.2/modular/sortable.esm.js"
pin "@avo-hq/marksmith", to: "@avo-hq--marksmith.js" # @0.4.7
