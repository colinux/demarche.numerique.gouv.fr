# frozen_string_literal: true

describe EditableChamp::DossierLinkComponent, type: :component do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:user) { dossier.user }
  let(:tdc) { procedure.active_revision.type_de_champs.first }
  let(:champ) { dossier.champs.first }

  subject(:render) do
    component = nil
    ActionView::Base.empty.form_for(champ, url: '/') do |form|
      component = EditableChamp::EditableChampComponent.new(champ:, form:)
    end

    render_inline(component)
  end

  context 'when the admin did not limit procedures' do
    it 'renders a free numeric text input' do
      render

      expect(page).to have_css('input[type="text"]')
      expect(page).not_to have_css('select')
      expect(page).not_to have_css('react-component')
    end
  end

  describe 'the field hint' do
    context 'when the admin did not limit procedures' do
      it 'invites the user to type a dossier number' do
        render

        expect(page).to have_text('Format attendu')
      end
    end

    context 'when the admin limited the field to some procedures' do
      before { tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [create(:procedure).id]) }

      it 'invites the user to select a dossier' do
        render

        expect(page).to have_text('Sélectionnez le numéro')
      end
    end
  end

  context 'when the admin limited the field to some procedures' do
    let(:linked_procedure) { create(:procedure, libelle: 'Démarche A') }

    before { tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [linked_procedure.id]) }

    context 'with fewer than 20 dossiers submitted by the user' do
      let!(:user_dossier) { create(:dossier, :en_construction, procedure: linked_procedure, user:) }
      let!(:other_user_dossier) { create(:dossier, :en_construction, procedure: linked_procedure) }
      let!(:brouillon) { create(:dossier, procedure: linked_procedure, user:) }

      it 'renders a grouped select with only the dossiers submitted by the user' do
        render

        expect(page).to have_css('select optgroup[label*="Démarche A"]')
        expect(page).to have_css("select option[value='#{user_dossier.id}']")
        expect(page).not_to have_css("select option[value='#{other_user_dossier.id}']")
        expect(page).not_to have_css("select option[value='#{brouillon.id}']")
      end
    end

    context 'when the user has no dossier on an allowed procedure' do
      it 'renders a disabled option explaining there is no dossier' do
        render

        expect(page).to have_css('select optgroup[label*="Démarche A"] option[disabled]', text: 'Vous n’avez déposé aucun dossier sur cette démarche.')
      end
    end

    context 'with at least the combobox threshold of dossiers' do
      before do
        stub_const("#{described_class}::COMBOBOX_THRESHOLD", 1)
        create(:dossier, :en_construction, procedure: linked_procedure, user:)
      end

      it 'renders a searchable combobox grouped by procedure without separators' do
        render

        expect(page).to have_css('react-component[name="ComboBox/SingleComboBox"]')
        expect(page).not_to have_css('select')

        props = JSON.parse(page.find('react-component')['props'])
        expect(props['sections'].first['label']).to eq('Démarche « Démarche A »')
      end
    end

    context 'when the current dossier itself belongs to an allowed procedure' do
      let(:dossier) { create(:dossier, :en_construction, procedure:) }

      before { tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [procedure.id]) }

      it 'does not offer the current dossier as a link target' do
        render

        expect(page).not_to have_css("select option[value='#{dossier.id}']")
      end
    end
  end
end
