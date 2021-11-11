import { LightningElement, api, track } from "lwc";
import getOrderSummary from "@salesforce/apex/B2BCheckoutSummaryController.getOrderSummary";

export default class B2BOrderCheckoutSummary extends LightningElement {
  @api recordId;

  @track showError = false;
  @track showSummary = false;
  @track showFreight = false;
  @track showFedEx = false;
  @track shippingCharge = 0;
  @track orderSummary;
  @track chargeLines = [];

  connectedCallback() {
    getOrderSummary({ orderSummaryId: this.recordId })
      .then((result) => {
        this.orderSummary = result.orderSummary;
        this.chargeLines = result.chargeLines;
        this.showFreight = result.includesFreight;
        this.showFedEx = result.includesFedEx;
        if (this.chargeLines && this.chargeLines.length > 0) {
          const shipping = this.chargeLines[0];
          if (shipping) {
            this.shippingCharge = shipping.TotalPrice;
          } 
        }
        this.showSummary = true;
      })
      .catch((error) => {
        console.error(error);
        this.showError = true;
      });
  }

  get grandTotalAmount() {
    return this.orderSummary.GrandTotalAmount;
  }
}
