import { toggle } from '@utils';
import { ApplicationController } from './application_controller';

function onVisibleEnableInputs(element: HTMLInputElement) {
  element.disabled = false;
  element.required = true;
}

function onHiddenDisableInputs(element: HTMLInputElement) {
  element.disabled = true;
  element.required = false;
}

export class ForTiersController extends ApplicationController {
  static targets = [
    'emailContainer',
    'emailInput',
    'notificationMethodCheckbox'
  ];

  declare notificationMethodCheckboxTarget: HTMLInputElement;
  declare emailContainerTarget: HTMLElement;
  declare emailInputTarget: HTMLInputElement;

  connect() {
    this.toggleEmailInput();
  }

  toggleEmailInput() {
    const isEmailSelected = this.notificationMethodCheckboxTarget.checked;

    toggle(this.emailContainerTarget, isEmailSelected);

    if (isEmailSelected) {
      onVisibleEnableInputs(this.emailInputTarget);
    } else {
      onHiddenDisableInputs(this.emailInputTarget);
    }
  }
}
