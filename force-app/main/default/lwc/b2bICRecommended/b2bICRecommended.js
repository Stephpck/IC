import { LightningElement, api, wire, track } from 'lwc';
import communityId from '@salesforce/community/Id';
import getRelatedProductsList from '@salesforce/apex/B2BICRecommendedController.getRelatedProductsList';

export default class B2bICRecommended extends LightningElement {
    
    @api recordId;
    @api effectiveAccountId;

    @track relatedProductsList;
    
    connectedCallback() {

        getRelatedProductsList({communityId: communityId, recordId: this.recordId, effectiveAccountId: this.effectiveAccountId ? this.effectiveAccountId : null})
        .then(data => {
          if (data) {
            this.relatedProductsList = data.map((product) => {
                const imgUrl = product.images != null && product.images.length > 0 ? product.images[0].url : '';
                const imgAltText = product.images != null && product.images.length > 0 ? product.images[0].alternativeText : '';
                const imgTitle = product.images != null && product.images.length > 0 ? product.images[0].title : '';
                const listPrice = product.price != null ? product.price.listPrice : '';
                return {...product, imgUrl: imgUrl, imgAltText: imgAltText, imgTitle: imgTitle, listPrice: listPrice};
              });
          }
        })
        .catch((err) => {
          console.log(err);
        })

    }

    get hasRecommendedProducts() {
        return this.relatedProductsList != null && this.relatedProductsList.length > 0;
    }

}