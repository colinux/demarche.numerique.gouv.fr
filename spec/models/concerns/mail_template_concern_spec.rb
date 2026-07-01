# frozen_string_literal: true

describe MailTemplateConcern do
  let(:procedure) { create(:procedure, :with_type_de_champ) }
  let(:mail) { Mails::ReceivedMail.default_for_procedure(procedure) }
  let(:dossier) { create(:dossier, procedure: procedure) }
  let(:dossier2) { create(:dossier, procedure: procedure) }
  let(:initiated_mail) { create(:initiated_mail, procedure: procedure) }
  let(:justificatif) { fixture_file_upload('spec/fixtures/files/piece_justificative_0.pdf', 'application/pdf') }

  shared_examples "can replace tokens in template" do
    describe 'with no token to replace' do
      let(:template) { '[demarche.numerique.gouv.fr] rien à remplacer' }
      it do
        is_expected.to eq("[demarche.numerique.gouv.fr] rien à remplacer")
      end
    end

    describe 'with one token to replace' do
      let(:template) { '[demarche.numerique.gouv.fr] Dossier : --numéro du dossier--' }
      it do
        is_expected.to eq("[demarche.numerique.gouv.fr] Dossier : #{dossier.id}")
      end
    end

    describe 'with multiples tokens to replace' do
      let(:template) { '[demarche.numerique.gouv.fr] --numéro du dossier-- --libellé démarche-- --lien dossier--' }
      it do
        expected =
          "[demarche.numerique.gouv.fr] #{dossier.id} #{dossier.procedure.libelle} " +
          "<a target=\"_blank\" rel=\"noopener\" href=\"http://test.host/dossiers/#{dossier.id}\">http://test.host/dossiers/#{dossier.id}</a>"

        is_expected.to eq(expected)
      end
    end
  end

  describe '#subject_for_dossier' do
    before { initiated_mail.subject = template }
    subject { initiated_mail.subject_for_dossier(dossier) }

    it_behaves_like "can replace tokens in template"
  end

  describe '#body_for_dossier' do
    before { initiated_mail.body = template }
    subject { initiated_mail.body_for_dossier(dossier) }

    it_behaves_like "can replace tokens in template"
  end

  describe 'tags' do
    describe 'in initiated mail' do
      it "does not treat date de passage en instruction as a tag" do
        expect(initiated_mail.tags).not_to include(include({ libelle: 'date de passage en instruction' }))
      end
    end

    describe 'in received mail' do
      let(:received_mail) { create(:received_mail, procedure: procedure) }

      it "treats date de passage en instruction as a tag" do
        expect(received_mail.tags).to include(include({ libelle: 'date de passage en instruction' }))
      end
    end

    describe '--lien attestation--' do
      let(:attestation_template) { build(:attestation_template, activated: true) }
      let(:procedure) { create(:procedure, attestation_acceptation_template: attestation_template) }

      subject { mail.body_for_dossier(dossier) }

      context 'acceptation' do
        let(:kind) { AttestationTemplate.kinds.fetch(:acceptation) }

        before do
          dossier.accepte!
          AttestationPdfGenerationJob.perform_now(dossier)
          dossier.reload
          mail.body = "--lien attestation--"
        end

        describe "in closed mail without justificatif" do
          let(:mail) { create(:closed_mail, procedure: procedure) }
          it do
            is_expected.to eq("<a target=\"_blank\" rel=\"noopener\" href=\"http://test.host/dossiers/#{dossier.id}/attestation\">http://test.host/dossiers/#{dossier.id}/attestation</a>")
            is_expected.to_not include("Télécharger le justificatif")
          end
        end

        describe "in closed mail with justificatif" do
          before do
            dossier.justificatif_motivation.attach(justificatif)
          end
          let(:mail) { create(:closed_mail, procedure: procedure) }

          it do
            expect(dossier.justificatif_motivation).to be_attached
            is_expected.to include("<a target=\"_blank\" rel=\"noopener\" href=\"http://test.host/dossiers/#{dossier.id}/attestation\">http://test.host/dossiers/#{dossier.id}/attestation</a>")
            is_expected.to_not include("Télécharger le justificatif")
          end
        end

        describe "in refuse mail" do
          let(:mail) { create(:refused_mail, procedure: procedure) }

          it { is_expected.to include("<a target=\"_blank\" rel=\"noopener\" href=\"http://test.host/dossiers/#{dossier.id}/attestation\">http://test.host/dossiers/#{dossier.id}/attestation</a>") }
        end

        describe "in without continuation mail" do
          let(:mail) { create(:without_continuation_mail, procedure: procedure) }

          it { is_expected.to eq("--lien attestation--") }
        end
      end
    end

    shared_examples 'inserting the --lien document justificatif-- tag' do
      let(:procedure) { create(:procedure) }

      subject { mail.body_for_dossier(dossier) }

      before do
        mail.body = "--lien document justificatif--"
      end

      describe 'without justificatif' do
        it { is_expected.to include("[l’instructeur n’a pas joint de document supplémentaire]") }
      end

      describe 'with justificatif' do
        before do
          dossier.justificatif_motivation.attach(justificatif)
        end
        it do
          expect(dossier.justificatif_motivation).to be_attached
          is_expected.to include("Télécharger le document justificatif")
        end
      end
    end

    context 'in closed mail' do
      let(:mail) { create(:closed_mail, procedure: procedure) }
      it_behaves_like 'inserting the --lien document justificatif-- tag'
    end

    context 'in refused mail' do
      let(:mail) { create(:refused_mail, procedure: procedure) }
      it_behaves_like 'inserting the --lien document justificatif-- tag'
    end

    context 'in without continuation mail' do
      let(:mail) { create(:without_continuation_mail, procedure: procedure) }
      it_behaves_like 'inserting the --lien document justificatif-- tag'
    end

    context 'sva/svr' do
      let(:procedure) { create(:procedure, :sva) }
      let(:received_mail) { create(:received_mail, procedure:) }
      it "treats date de passage en instruction as a tag" do
        expect(received_mail.tags).to include(include({ libelle: 'date prévisionnelle SVA/SVR' }))
      end
    end
  end

  describe '#replace_tags' do
    before { initiated_mail.body = "n --numéro du dossier--" }
    it "avoids side effects" do
      expect(initiated_mail.body_for_dossier(dossier)).to eq("n #{dossier.id}")
      expect(initiated_mail.body_for_dossier(dossier2)).to eq("n #{dossier2.id}")
    end
  end

  describe '#update_rich_body' do
    before { initiated_mail.update(body: "Voici le corps du mail") }

    it { expect(initiated_mail.rich_body.to_plain_text).to eq(initiated_mail.body) }
  end

  describe '#tiptap_inline_nodes_for' do
    it 'résout --numéro du dossier-- en mention' do
      nodes = mail.tiptap_inline_nodes_for('Dossier --numéro du dossier--')
      expect(nodes).to eq([
        { "type" => "text", "text" => "Dossier " },
        { "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } },
      ])
    end

    it 'garde un libellé inconnu en texte littéral' do
      nodes = mail.tiptap_inline_nodes_for('Bonjour --libellé inexistant--')
      expect(nodes).to eq([
        { "type" => "text", "text" => "Bonjour " },
        { "type" => "text", "text" => "--libellé inexistant--" },
      ])
    end

    it 'retourne [] pour une chaîne vide' do
      expect(mail.tiptap_inline_nodes_for('')).to eq([])
    end

    it 'préserve un texte composé uniquement d’espaces' do
      expect(mail.tiptap_inline_nodes_for(' ')).to eq([{ "type" => "text", "text" => " " }])
    end
  end

  describe 'accesseurs tiptap' do
    it 'tiptap_body= parse le JSON dans json_body' do
      mail.tiptap_body = '{"type":"doc","content":[]}'
      expect(mail.json_body).to eq({ "type" => "doc", "content" => [] })
    end

    it 'tiptap_body_or_default renvoie json_body si présent' do
      mail.json_body = { "type" => "doc", "content" => [{ "type" => "paragraph" }] }
      expect(JSON.parse(mail.tiptap_body_or_default)).to eq(mail.json_body)
    end

    it 'tiptap_body_or_default convertit le body legacy sinon' do
      mail.json_body = nil
      mail.body = '<div>Bonjour <strong>usager</strong></div>'
      doc = JSON.parse(mail.tiptap_body_or_default)
      expect(doc["content"].first["type"]).to eq("paragraph")
      expect(doc["content"].first["content"]).to include({ "type" => "text", "text" => "usager", "marks" => [{ "type" => "bold" }] })
    end

    it 'tiptap_subject_or_default convertit le subject legacy en doc mono-ligne' do
      mail.json_subject = nil
      mail.subject = 'Dossier --numéro du dossier--'
      doc = JSON.parse(mail.tiptap_subject_or_default)
      expect(doc["type"]).to eq("doc")
      expect(doc["content"].first["type"]).to eq("paragraph")
      expect(doc["content"].first["content"]).to include({ "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } })
    end
  end
end
