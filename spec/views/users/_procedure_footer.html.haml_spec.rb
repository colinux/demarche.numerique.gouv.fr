# frozen_string_literal: true

describe 'users/procedure_footer', type: :view do
  let(:service) { create(:service) }
  let(:dossier) {
    dossier = create(:dossier)
    dossier.procedure.service = service
    return dossier
  }

  subject { render 'users/procedure_footer', procedure: dossier.procedure, dossier: dossier }

  it "affiche les informations de contact" do
    expect(subject).to have_text(service.nom)
    expect(subject).to have_text(service.organisme)
    expect(subject).to have_text(service.telephone)
  end

  it "affiche les liens usuels requis" do
    expect(subject).to have_link("Accessibilité")
    expect(subject).to have_link("Mentions légales")
  end

  context "quand le dossier n’a pas de service associé" do
    let(:service) { nil }

    it do
      is_expected.to have_selector("footer")
      is_expected.to have_link("Accessibilité")
      is_expected.not_to have_text('téléphone')
    end
  end

  describe '#cadre_juridique' do
    context 'when an external link is provided' do
      before { dossier.procedure.update(cadre_juridique: "http://google.fr") }
      it { is_expected.to have_link("Texte cadrant la demande d’information", href: 'http://google.fr') }
    end

    context 'when there is deliberation attached' do
      before { dossier.procedure.update(cadre_juridique: nil, deliberation: fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf')) }
      it { is_expected.to have_link("Texte cadrant la demande d’information") }
    end
  end

  describe '#france_service_link' do
    let(:france_service_link_text) { I18n.t('users.procedure_footer.support_links.france_service.title') }

    context "when procedure belongs to Ministère de l’Intérieur" do
      it { is_expected.to have_link(france_service_link_text) }
    end

    context "when procedure does not belong to Ministère de l’Intérieur" do
      before do
        dossier.procedure.zones << Zone.find_by!(acronym: 'MI')
      end

      it { is_expected.not_to have_link(france_service_link_text) }
    end
  end

  describe '#lien_dpo' do
    context "when there is not lien_dpo" do
      before { dossier.procedure.update(lien_dpo: nil) }
      it { is_expected.not_to have_text('Contacter le Délégué à la Protection des Données') }
    end

    context "when there is a lien_dpo with an email" do
      before { dossier.procedure.update(lien_dpo: 'dpo@beta.gouv.fr') }
      it { is_expected.to have_selector('a[href="mailto:dpo@beta.gouv.fr?subject="]') }
    end

    context "when a schemaless link was stored before links were normalized" do
      before do
        # raw sql: an attribute write would normalize it
        Procedure.where(id: dossier.procedure.id).update_all("lien_dpo = 'beta.gouv.fr'")
        dossier.procedure.reload
      end
      it { is_expected.to have_link('Contacter le Délégué à la Protection des Données', href: '//beta.gouv.fr') }
    end

    context "when there is a lien_dpo with a link with http:// schema" do
      before { dossier.procedure.update(lien_dpo: 'http://beta.gouv.fr') }
      it { is_expected.to have_link('Contacter le Délégué à la Protection des Données', href: 'http://beta.gouv.fr') }
    end

    context "when there is a lien_dpo with a link with https:// schema" do
      before { dossier.procedure.update(lien_dpo: 'https://beta.gouv.fr') }
      it { is_expected.to have_link('Contacter le Délégué à la Protection des Données', href: 'https://beta.gouv.fr') }
    end

    context "when a javascript link was stored before validation rejected it" do
      before { dossier.procedure.update_column(:lien_dpo, 'javascript:alert(window.location)//@almond.eu') }
      it { is_expected.not_to have_text('Contacter le Délégué à la Protection des Données') }
    end

    ['JaVaScRiPt:alert(1)//@x.fr', 'vbscript:msgbox(1)//@x.fr', 'data:text/html,<script>alert(1)</script>@x.fr', 'javascript://x@x.fr/%0Aalert(1)'].each do |lien_dpo|
      context "when #{lien_dpo.inspect} was stored before validation rejected it" do
        before { dossier.procedure.update_column(:lien_dpo, lien_dpo) }
        it { is_expected.not_to have_text('Contacter le Délégué à la Protection des Données') }
      end
    end

    context "when the scheme hides in an entity" do
      before { dossier.procedure.update_column(:lien_dpo, 'javascript&#58;alert(1)//@x.fr') }
      it { is_expected.to have_link('Contacter le Délégué à la Protection des Données', href: '//javascript&#58;alert(1)//@x.fr') }
    end

    ['" onmouseover="alert(1)" x="@x.fr', '"><script>alert(1)</script>@x.fr', 'https://x.fr/" onmouseover="alert(1)'].each do |lien_dpo|
      context "when #{lien_dpo.inspect} tries to break out of the href" do
        before { dossier.procedure.update_column(:lien_dpo, lien_dpo) }

        it "keeps it inside the href" do
          is_expected.to have_link('Contacter le Délégué à la Protection des Données')
          is_expected.not_to have_css('[onmouseover]')
          is_expected.not_to have_css('script', visible: :all)
        end
      end
    end
  end
end
