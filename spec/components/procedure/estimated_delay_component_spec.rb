# frozen_string_literal: true

describe Procedure::EstimatedDelayComponent, type: :component do
  let(:procedure) { create(:procedure, :published) }
  let(:usual_traitement_time) { [1.day, 5.days, 1.month] }

  before do
    allow(procedure).to receive(:stats_usual_traitement_time).and_return(usual_traitement_time)
  end

  subject { render_inline(described_class.new(procedure:)) }

  describe 'render?' do
    context 'when estimated_processing_duration_visible is false' do
      before { procedure.update!(estimated_processing_duration_visible: false) }

      it 'does not render' do
        subject
        expect(page).to have_no_text("Dans le meilleur des cas")
      end

      context 'with fallback_to_placeholder: true' do
        subject { render_inline(described_class.new(procedure:, fallback_to_placeholder: true)) }

        it 'does not render anything either' do
          subject
          expect(page).to have_no_text("Dans le meilleur des cas")
        end

        context 'when the procedure is a brouillon without stats' do
          let(:procedure) { create(:procedure) }
          let(:usual_traitement_time) { nil }

          it 'does not render the placeholder' do
            subject
            expect(page).to have_no_text("[indication du délai]")
          end
        end
      end
    end

    context 'when estimated_processing_duration_visible is true' do
      it 'renders the component' do
        subject
        expect(page).to have_text("Dans le meilleur des cas")
      end
    end

    context 'when a published procedure has no stats yet' do
      let(:usual_traitement_time) { nil }

      subject { render_inline(described_class.new(procedure:, fallback_to_placeholder: true)) }

      it 'does not render the placeholder' do
        subject
        expect(page).to have_no_text("[indication du délai]")
      end
    end
  end

  describe 'placeholder mode for brouillon procedure' do
    let(:procedure) { create(:procedure) }
    let(:usual_traitement_time) { nil }

    it 'does not render without fallback_to_placeholder' do
      subject
      expect(page).not_to have_text("[indication du délai]")
    end

    context 'with fallback_to_placeholder: true' do
      subject { render_inline(described_class.new(procedure:, fallback_to_placeholder: true)) }

      it 'renders with placeholder text' do
        subject
        expect(page).to have_text("Dans le meilleur des cas")
        expect(page).to have_text("[indication du délai]")
        expect(page).to have_text("[indication du délai moyen]")
      end

      it 'shows all three estimation lines' do
        subject
        expect(page).to have_css('li', minimum: 3)
      end
    end
  end
end
