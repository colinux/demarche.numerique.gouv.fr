import { fileSizeErrorMessage } from '../shared/attachment-error';
import { ApplicationController } from './application_controller';
export class FileInputResetController extends ApplicationController {
  static targets = ['fileList'];
  declare fileListTarget: HTMLElement;

  // A native picker replaces the input's files: keep the previous picks here.
  private files: File[] = [];

  connect() {
    super.connect();
    this.files = Array.from(this.fileInput?.files ?? []);
    this.updateFileList();
    this.element.addEventListener('change', (event) => {
      if (
        event.target instanceof HTMLInputElement &&
        event.target.type === 'file'
      ) {
        this.appendFiles(Array.from(event.target.files ?? []));
      }
    });
  }

  appendFiles(picked: File[]) {
    const isNew = (file: File) =>
      !this.files.some(
        (kept) =>
          kept.name === file.name &&
          kept.size === file.size &&
          kept.lastModified === file.lastModified
      );

    this.files = [...this.files, ...picked.filter(isNew)];
    this.syncInput();
    this.updateFileList();
  }

  updateFileList() {
    const fileInput = this.fileInput;
    const files = this.files;
    this.fileListTarget.innerHTML = '';

    const deleteLabel =
      this.element.getAttribute('data-delete-label') || 'Delete';

    Array.from(files).forEach((file, index) => {
      const container = document.createElement('li');
      container.classList.add('fr-mb-1w');

      const row = document.createElement('div');
      row.classList.add('flex', 'flex-gap-2');

      const deleteButton = this.createDeleteButton(deleteLabel, index);
      row.appendChild(deleteButton);

      const listItem = document.createElement('span');
      listItem.setAttribute('id', 'filename-' + index);
      listItem.textContent = file.name;

      row.appendChild(listItem);
      container.appendChild(row);

      const sizeError = fileInput && fileSizeErrorMessage(fileInput, file);
      if (sizeError) {
        container.appendChild(this.createSizeError(sizeError));
      }

      this.fileListTarget.appendChild(container);
    });
  }

  createSizeError(message: string) {
    const error = document.createElement('p');
    error.classList.add('fr-error-text');
    error.setAttribute('role', 'alert');
    error.innerHTML = message;

    return error;
  }

  createDeleteButton(deleteLabel: string, index: number) {
    const button = document.createElement('button');
    button.setAttribute('id', 'delete-button-' + index);
    button.setAttribute(
      'aria-labelledby',
      'delete-button-' + index + ' filename-' + index
    );
    button.textContent = deleteLabel;
    button.classList.add(
      'fr-btn',
      'fr-btn--tertiary',
      'fr-btn--sm',
      'fr-icon-delete-line'
    );

    button.addEventListener('click', (event) => {
      event.preventDefault();
      this.removeFile(index);
    });

    return button;
  }

  removeFile(index: number) {
    this.files = this.files.filter((_, i) => i !== index);
    this.syncInput();
    this.updateFileList();
    this.focusAfterRemoval(index);
  }

  // The focused button is gone: move focus to the next row, or the input.
  private focusAfterRemoval(index: number) {
    const buttons = this.fileListTarget.querySelectorAll('button');
    const next = buttons[Math.min(index, buttons.length - 1)];
    (next ?? this.fileInput)?.focus();
  }

  private syncInput() {
    const fileInput = this.fileInput;
    if (!fileInput) return;

    const dataTransfer = new DataTransfer();
    this.files.forEach((file) => dataTransfer.items.add(file));
    fileInput.files = dataTransfer.files;
  }

  private get fileInput(): HTMLInputElement | null {
    return this.element.querySelector(
      'input[type="file"]'
    ) as HTMLInputElement | null;
  }
}
