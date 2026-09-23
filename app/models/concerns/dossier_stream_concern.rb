# frozen_string_literal: true

module DossierStreamConcern
  extend ActiveSupport::Concern

  MAIN_STREAM = 'main'
  USER_BUFFER_STREAM = 'user:buffer'
  INSTRUCTEUR_BUFFER_STREAM = 'instructeur:buffer'
  USER_HISTORY_STREAM = 'user:history'
  HISTORY_STREAM = 'history:'

  # HISTORY_STREAM is a prefix, so it cannot be listed: a history stream is
  # "history:<timestamp>". Enumerate the others instead.
  NON_HISTORY_STREAMS = [MAIN_STREAM, USER_BUFFER_STREAM, INSTRUCTEUR_BUFFER_STREAM, USER_HISTORY_STREAM].freeze

  def stream
    @stream || MAIN_STREAM
  end

  def main_stream?
    stream == MAIN_STREAM
  end

  def user_buffer_stream?
    stream == USER_BUFFER_STREAM
  end

  def instructeur_buffer_stream?
    stream == INSTRUCTEUR_BUFFER_STREAM
  end

  def user_history_stream?
    stream == USER_HISTORY_STREAM
  end

  def with_update_stream(user, &block)
    if can_update_as_user?(user)
      with_stream(USER_BUFFER_STREAM, &block)
    elsif can_update_as_instructeur?(user)
      with_stream(INSTRUCTEUR_BUFFER_STREAM, &block)
    else
      with_stream(MAIN_STREAM, &block)
    end
  end

  def with_main_stream(&block)
    with_stream(MAIN_STREAM, &block)
  end

  def with_instructeur_buffer_stream(&block)
    with_stream(INSTRUCTEUR_BUFFER_STREAM, &block)
  end

  def with_user_history_stream(&block)
    with_stream(USER_HISTORY_STREAM, &block)
  end

  def with_champ_stream(champ, &block)
    with_stream(champ.stream, &block)
  end

  def can_update_as_user?(user)
    return false unless en_construction?
    user.owns_or_invite?(self)
  end

  def can_update_as_instructeur?(user)
    return false unless en_construction?
    return false unless procedure.instructeurs_can_edit_dossiers?
    return false unless user.instructeur?
    return false if can_update_as_user?(user)
    groupe_instructeur.instructeurs.include?(user.instructeur)
  end

  private

  def with_stream(stream)
    if block_given?
      previous_stream = @stream
      @stream = stream
      reset_champs_cache
      result = yield
      @stream = previous_stream
      reset_champs_cache
      result
    else
      @stream = stream
      reset_champs_cache
      self
    end
  end
end
