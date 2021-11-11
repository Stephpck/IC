import { LightningElement, track } from 'lwc';
import getFAQList from '@salesforce/apex/B2BICFAQController.getFAQList';

export default class LightningExampleAccordionBasic extends LightningElement {

    @track faqList;
    
    connectedCallback() {

        getFAQList({})
        .then(data => {
          if (data) {
            this.faqList = data.map((faq) => {
              const nameId = faq.name.replace(/\s+/g, '');
              return {...faq, nameId: nameId};
            });
          }
        })
        .catch((err) => {
          console.log(err);
        })

    }

    renderedCallback() {
      this.faqList.forEach(function(faq) {
        let answerElem = this.template.querySelector('.' + faq.nameId);
        if(answerElem) {
          if(faq.answer) answerElem.innerHTML = faq.answer;
        }
      }, this);
    }

    get hasFAQList() {
        return this.faqList != null && this.faqList.length > 0;
    }

}
