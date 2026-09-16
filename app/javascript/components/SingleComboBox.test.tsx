// La combobox ne soumet que ce qui diffère de ce que le serveur connaît : les valeurs
// rendues. Quand le serveur re-rend le champ avec une autre valeur (préremplissage), les
// props changent sur place : revenir à la valeur d'origine est alors un vrai changement,
// qui doit être soumis — sinon l'écran et le serveur divergent.
import './process-env-shim';
import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { userEvent, page } from '@vitest/browser/context';
import { createRoot, type Root } from 'react-dom/client';

import { SingleComboBox } from './ComboBox';

vi.mock('@lingui/react/macro', () => ({
  useLingui: () => ({ t: (s: TemplateStringsArray | string) => String(s) }),
  Trans: ({ children }: { children: React.ReactNode }) => children,
  Plural: ({ _0, value }: { _0: React.ReactNode; value: number }) =>
    value === 0 ? _0 : `${value} choix sélectionnés`
}));

const items = [
  { label: 'Alpha', value: 'a' },
  { label: 'Beta', value: 'b' }
];

function Champ({ selectedKey }: { selectedKey: string }) {
  return (
    <form>
      <SingleComboBox
        label="Choix"
        items={items}
        selectedKey={selectedKey}
        name="champ[value]"
      />
    </form>
  );
}

let container: HTMLDivElement;
let root: Root;
let changes: number;

beforeEach(() => {
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
  changes = 0;
  container.addEventListener('change', () => changes++);
  root.render(<Champ selectedKey="a" />);
});

afterEach(() => {
  root.unmount();
  container.remove();
});

function hiddenInput(name: string) {
  return container.querySelector<HTMLInputElement>(`input[name="${name}"]`)!;
}

async function select(label: string) {
  const input = page.getByRole('combobox', { name: 'Choix' });
  await userEvent.fill(input, label.slice(0, 3));
  await expect.element(page.getByRole('option', { name: label })).toBeVisible();
  await userEvent.keyboard('{ArrowDown}{Enter}');
  await expect.element(input).toHaveValue(label);
}

suite('SingleComboBox with a preselected item', () => {
  test('re-selecting the current item submits nothing', async () => {
    await select('Alpha');

    await new Promise((resolve) => requestAnimationFrame(resolve));
    expect(changes).toBe(0);
    expect(hiddenInput('champ[value]').value).toBe('a');
  });

  test('selecting another item submits it', async () => {
    await select('Beta');

    await expect.poll(() => changes).toBe(1);
    expect(hiddenInput('champ[value]').value).toBe('b');
  });

  test('going back to a value the server has replaced submits it', async () => {
    const input = page.getByRole('combobox', { name: 'Choix' });
    await expect.element(input).toHaveValue('Alpha');

    root.render(<Champ selectedKey="b" />);
    await expect.element(input).toHaveValue('Beta');
    expect(hiddenInput('champ[value]').value).toBe('b');
    expect(changes).toBe(0);

    await select('Alpha');

    await expect.poll(() => changes).toBe(1);
    expect(hiddenInput('champ[value]').value).toBe('a');
  });
});
