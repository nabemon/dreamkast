class SpeakerForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :name,
                :name_mother_tongue,
                :email,
                :sub,
                :profile,
                :company,
                :job_title,
                :twitter_id,
                :github_id,
                :avatar,
                :conference_id,
                :additional_documents,
                :talks

  delegate :persisted?, to: :speaker

  concerning :TalksBuilder do
    attr_accessor :talks

    def talks
      @talks ||= []
    end

    def talks_attributes=(attributes)
      proposal_item_config_labels = @conference.proposal_item_configs.map(&:label).uniq
      @talks ||= []
      @destroy_talks ||= []
      attributes.each do |_i, params|
        if params.key?(:id)
          # talk is already exists
          if params[:_destroy] == "1"
            @destroy_talks << @speaker.talks.find(params[:id])
          else
            params.delete(:_destroy)
            talk = @speaker.talks.find(params[:id])
            if @sponsor.present? && params[:sponsor_session] == "true"
              params[:sponsor_id] = @sponsor.id
              params.delete(:sponsor_session)
            else
              params[:sponsor_id] = nil
              params.delete(:sponsor_session)
            end

            proposal_item_params = {}
            proposal_item_config_labels.each do |label|
              proposal_item_params[label.pluralize] = params.delete(label.pluralize)
            end
            proposal_item_config_labels.each do |label|
              talk.create_or_update_proposal_item(label, proposal_item_params[label.pluralize]) if proposal_item_params[label.pluralize].present?
            end

            talk.update(params)
            @talks << talk
          end
        else
          # talk doesn't exists
          unless params[:_destroy] == "1"
            params.delete(:_destroy)
            params[:show_on_timetable] = true
            params[:video_published] = true
            if @sponsor.present? && params[:sponsor_session] == "true"
              params[:sponsor_id] = @sponsor.id
              params.delete(:sponsor_session)
            else
              params[:sponsor_id] = nil
              params.delete(:sponsor_session)
            end
            proposal_item_params = {}
            proposal_item_config_labels.each do |label|
              proposal_item_params[label.pluralize] = params.delete(label.pluralize)
            end
            t = Talk.new(params)
            proposal_item_config_labels.each do |label|
              t.create_or_update_proposal_item(label, proposal_item_params[label.pluralize]) if proposal_item_params[label.pluralize].present?
            end
            @talks << t
          end
        end
      end
    rescue => e
      puts e
      false
    end
  end

  def initialize(attributes = nil, speaker: Speaker.new, sponsor: nil, conference: nil)
    @speaker = speaker
    @sponsor = sponsor
    @conference = conference
    @talks ||= []
    @destroy_talks ||= []
    attributes ||= default_attributes
    super(attributes)
  end

  def speaker
    @speaker
  end

  def save
    return if invalid?

    ActiveRecord::Base.transaction do
      speaker.update!(name: name, name_mother_tongue: name_mother_tongue, profile: profile, company: company, job_title: job_title, twitter_id: twitter_id, github_id: github_id, avatar: avatar, conference_id: conference_id, sub: sub, email: email, additional_documents: additional_documents)
      @destroy_talks.each do |talk|
        proposal = talk.proposal
        talk_speaker = TalksSpeaker.new(talk_id: talk.id, speaker_id: speaker.id)
        talk.destroy!
        talk_speaker.destroy!
        proposal.destroy! if proposal
      end
      @talks.each do |talk|
        if talk.persisted?
          talk.save!
        else
          talk.save!
          talk_speaker = TalksSpeaker.new(talk_id: talk.id, speaker_id: speaker.id)
          talk_speaker.save!

          proposal = Proposal.new(conference_id: conference_id, talk_id: talk.id)
          proposal.save!
        end
      end
    end
  rescue => e
    puts "failed to save: #{e}"
    false
  end

  def to_model
    speaker
  end

  def load
    @talks = @speaker.talks
  end

  attr_reader :speaker

  private

  def default_attributes
    {
      name: speaker.name,
      name_mother_tongue: speaker.name_mother_tongue,
      email: speaker.email,
      sub: speaker.sub,
      profile: speaker.profile,
      company: speaker.company,
      job_title: speaker.job_title,
      twitter_id: speaker.twitter_id,
      github_id: speaker.github_id,
      avatar: speaker.avatar_data,
      additional_documents: speaker.additional_documents,
      talks: talks
    }
  end
end
