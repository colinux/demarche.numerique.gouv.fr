# frozen_string_literal: true

class Champs::PieceJustificativeController < Champs::ChampController
  def show
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to(root_url) }
    end
  end

  def update
    if attach_piece_justificative
      render :show
    else
      render json: { errors: @champ.errors.full_messages }, status: 422
    end
  end

  def template
    template = @champ.type_de_champ.piece_justificative_template

    # The link may be stale: the template can be gone from the dossier revision
    # since the page was rendered (rebase, template removed).
    return redirect_back_or_to(root_url, alert: t('.not_available')) if !template.attached?

    redirect_to rails_blob_url(template.blob, disposition: 'attachment')
  end

  private

  def policy_class
    Champs::PieceJustificativeChampPolicy
  end

  def attach_piece_justificative
    save_succeed = Attachment::PieceJustificativeService.attach_champ_pj(@champ, params[:blob_signed_id])

    if save_succeed
      @champ.update_timestamps
    end

    save_succeed
  end
end
