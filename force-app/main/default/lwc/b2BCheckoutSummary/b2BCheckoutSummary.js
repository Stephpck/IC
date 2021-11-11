import { LightningElement, api, track } from "lwc";
import getCartSummary from "@salesforce/apex/B2BCheckoutSummaryController.getCartSummary";

export default class B2BCheckoutSummary extends LightningElement {
  @api cartId;

  @track showError = false;
  @track showSummary = false;
  @track showFreight = false;
  @track showFedEx = false;
  @track shippingCharge = 0;
  @track cart;
  @track chargeLines = [];

  connectedCallback() {
    getCartSummary({ cartId: this.cartId })
      .then((result) => {
        this.cart = result.cart;
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
    return this.cart.GrandTotalAmount;
  }
}
