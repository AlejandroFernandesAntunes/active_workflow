module AgentHelper
  def agent_show_view(agent)
    name = agent.short_type.underscore
    if File.exist?(Rails.root.join('app', 'views', 'agents', 'agent_views', name, '_show.html.erb'))
      File.join('agents', 'agent_views', name, 'show')
    end
  end

  def workflow_links(agent)
    agent.workflows.map { |workflow|
      link_to(workflow.name, workflow, class: 'badge', style: style_colors(workflow))
    }.join(' ').html_safe
  end

  def agent_show_class(agent)
    agent.short_type.underscore.dasherize
  end

  def agent_schedule(agent, delimiter = ', ')
    return 'n/a' unless agent.can_be_scheduled?

    case agent.schedule
    when nil, 'never'
      agent_controllers(agent, delimiter) || 'Never'
    else
      [
        builtin_schedule_name(agent.schedule),
        *(agent_controllers(agent, delimiter))
      ].join(delimiter).html_safe
    end
  end

  def builtin_schedule_name(schedule)
    AgentHelper.builtin_schedule_name(schedule)
  end

  def self.builtin_schedule_name(schedule)
    schedule == 'every_7d' ? 'Every Monday' : schedule.humanize.titleize
  end

  def agent_controllers(agent, delimiter = ', ')
    if agent.controllers.present?
      agent.controllers.map { |agent|
        link_to(agent.name, agent_path(agent))
      }.join(delimiter).html_safe
    end
  end

  def agent_dry_run_with_message_mode(agent)
    case
    when agent.cannot_receive_messages?
      'no'.freeze
    when agent.cannot_be_scheduled?
      # incoming message is the only trigger for the agent
      'yes'.freeze
    else
      'maybe'.freeze
    end
  end

  def agent_type_icon(agent, agents)
    receiver_count = links_counter_cache(agents)[:links_as_receiver][agent.id] || 0
    control_count  = links_counter_cache(agents)[:control_links_as_controller][agent.id] || 0
    source_count   = links_counter_cache(agents)[:links_as_source][agent.id] || 0

    if control_count > 0 && receiver_count > 0
      content_tag('span') do
        concat icon_tag('fa-arrow-right')
        concat tag('br')
        concat icon_tag('fa-external-link-alt', class: 'icon-flipped')
      end
    elsif control_count > 0 && receiver_count == 0
      icon_tag('fa-external-link-alt', class: 'icon-flipped')
    elsif receiver_count > 0 && source_count == 0
      icon_tag('fa-arrow-right')
    elsif receiver_count == 0 && source_count > 0
      icon_tag('fa-arrow-left')
    elsif receiver_count > 0 && source_count > 0
      icon_tag('fa-exchange-alt')
    else
      icon_tag('fa-square')
    end
  end

  def agent_type_select_options
    Rails.cache.fetch('agent_type_select_options') do
      [['Select an Agent Type', 'Agent', { title: '' }]] + Agent.types.map { |type| [agent_type_to_human(type), type, { title: h(Agent.build_for_type(type.name, User.new(id: 0), {}).html_description.lines.first.strip) }] }
    end
  end

  def agent_types
    Agent.types.map do |type|
      agent = Agent.build_for_type(type.name, User.new(id: 0), {})
      {
        type: type,
        name: agent_type_to_human(type),
        description: agent.html_description
      }
    end
  end

  def relative_time(at, applicable)
    if applicable
      at ? Time.now - at : 31556995200 # 1000 years
    else
      63113902876 # 2000 years just in case
    end
  end

  private

  def links_counter_cache(agents)
    @counter_cache ||= {}
    @counter_cache[agents.__id__] ||= {}.tap do |cache|
      agent_ids = agents.map(&:id)
      cache[:links_as_receiver] = Hash[Link.where(receiver_id: agent_ids)
                                  .group(:receiver_id)
                                           .pluck(:receiver_id, Arel.sql('count(receiver_id) as id'))]
      cache[:links_as_source]   = Hash[Link.where(source_id: agent_ids)
                                  .group(:source_id)
                                           .pluck(:source_id, Arel.sql('count(source_id) as id'))]
      cache[:control_links_as_controller] = Hash[ControlLink.where(controller_id: agent_ids)
                                            .group(:controller_id)
                                                            .pluck(:controller_id, Arel.sql('count(controller_id) as id'))]
    end
  end
end
