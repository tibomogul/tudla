import { Controller } from "@hotwired/stimulus"
import { HillChart } from "hillchart"

export default class extends Controller {
  static values = { dots: Array, editable: { type: Boolean, default: true } }

  connect() {
    console.log("HillChart controller connected (editable=" + this.editableValue + ")");
    new HillChart(document.getElementById('chart'), {
      width: 500,
      height: 250,
      editable: this.editableValue,
      truncateLength: 15,
      dots: this.dotsValue
    });

    if (this.editableValue) {
      document.getElementById('chart').addEventListener('hillchart:save', (e) => {
        this.saveHillchartData(e.detail);
      });
    }
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
