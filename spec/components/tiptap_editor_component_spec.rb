# frozen_string_literal: true

describe TiptapEditorComponent, type: :component do
  let(:dossier_submitted_message) { build(:dossier_submitted_message) }
  let(:form) do
    ActionView::Helpers::FormBuilder.new(:dossier_submitted_message, dossier_submitted_message, vc_test_controller.view_context, {})
  end

  subject(:rendered) { render_inline(described_class.new(form:, field_name: :tiptap_body)) }

  it "renders the formatting toolbar without an underline button" do
    expect(rendered).to have_button("Gras")
    expect(rendered).to have_button("Italique")
    expect(rendered).not_to have_button("Souligné")
    expect(rendered.to_html).not_to include('data-tiptap-action="underline"')
  end

  context "with a custom actions list" do
    subject(:rendered) { render_inline(described_class.new(form:, field_name: :tiptap_body, actions: %w[bold strike])) }

    it "renders only the buttons matching the given actions" do
      expect(rendered).to have_button("Barré")
      expect(rendered).not_to have_button("Liste")
    end
  end

  it "does not render any tag button when tags: is not given" do
    expect(rendered).not_to have_css('[data-tiptap-target="tag"]')
  end

  it "rend la liste de tags dans le composant quand tags: est fourni" do
    render_inline(described_class.new(
      form: form, field_name: :tiptap_body,
      tags: { dossier: [{ id: 'dossier_number', libelle: 'numéro du dossier', description: '' }] }
    ))
    expect(page).to have_button('numéro du dossier')
    expect(page).to have_css('[data-tiptap-target="tag"]')
  end
end
