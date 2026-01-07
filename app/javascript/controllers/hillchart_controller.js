import { Controller } from "@hotwired/stimulus"
import { HillChart } from "hillchart"

export default class extends Controller {
  static values = { dots: Array }

  connect() {
    console.log("HillChart controller connected");
    const chart = new HillChart(document.getElementById('chart'), {
      width: 500,
      height: 250,
      editable: true,
      truncateLength: 15,
      dots: this.dotsValue
    });

    document.getElementById('chart').addEventListener('hillchart:save', (e) => {
      this.saveHillchartData(e.detail);
    });
  }

  saveHillchartData(data) {
    fetch(`/scopes/hillchart_update`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ hillchart_data: data })
    })
    .then(response => response.json())
    .then(result => {
      console.log('Hillchart data saved:', result);
    })
    .catch(error => {
      console.error('Error saving hillchart data:', error);
    });
  }
}
