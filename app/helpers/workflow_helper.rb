module WorkflowHelper
  def sla_status_class(invoice_workflow)
    return '' unless invoice_workflow.present? && has_sla_deadline?(invoice_workflow)

    if sla_overdue?(invoice_workflow)
      'text-red-600 bg-red-100'
    elsif sla_warning?(invoice_workflow)
      'text-yellow-600 bg-yellow-100'
    else
      'text-green-600 bg-green-100'
    end
  end

  def sla_status_text(invoice_workflow)
    return 'No SLA' unless invoice_workflow.present? && has_sla_deadline?(invoice_workflow)

    if sla_overdue?(invoice_workflow)
      time_overdue = time_since_deadline(invoice_workflow)
      "Overdue by #{time_overdue}"
    elsif sla_warning?(invoice_workflow)
      time_remaining = time_until_deadline(invoice_workflow)
      "Due in #{time_remaining}"
    else
      time_remaining = time_until_deadline(invoice_workflow)
      "Due in #{time_remaining}"
    end
  end

  def sla_icon(invoice_workflow)
    return 'clock' unless invoice_workflow.present?

    if sla_overdue?(invoice_workflow)
      'exclamation-triangle'
    elsif sla_warning?(invoice_workflow)
      'exclamation-circle'
    else
      'clock'
    end
  end

  def time_in_current_state(invoice_workflow)
    return 'Unknown' unless invoice_workflow&.dig('entered_current_state_at')

    entered_at = Time.parse(invoice_workflow['entered_current_state_at'])
    duration = Time.current - entered_at

    format_duration(duration)
  end

  def sla_progress_percentage(invoice_workflow)
    return 0 unless invoice_workflow.present? && has_sla_deadline?(invoice_workflow)

    entered_at = Time.parse(invoice_workflow['entered_current_state_at'])
    deadline = Time.parse(invoice_workflow['sla_deadline'])
    now = Time.current

    total_duration = deadline - entered_at
    elapsed_duration = now - entered_at

    return 100 if elapsed_duration >= total_duration

    percentage = (elapsed_duration / total_duration * 100).round
    [0, [percentage, 100].min].max
  end

  def sla_deadline_formatted(invoice_workflow)
    return nil unless has_sla_deadline?(invoice_workflow)

    deadline = Time.parse(invoice_workflow['sla_deadline'])
    deadline.strftime("%b %d, %Y at %I:%M %p")
  end

  private

  def sla_overdue?(invoice_workflow)
    return false unless has_sla_deadline?(invoice_workflow)

    deadline = Time.parse(invoice_workflow['sla_deadline'])
    Time.current > deadline
  end

  def sla_warning?(invoice_workflow)
    return false unless has_sla_deadline?(invoice_workflow)

    deadline = Time.parse(invoice_workflow['sla_deadline'])
    warning_threshold = deadline - 2.hours # Warning 2 hours before deadline

    Time.current > warning_threshold && Time.current <= deadline
  end

  def has_sla_deadline?(invoice_workflow)
    invoice_workflow&.dig('sla_deadline').present?
  end

  def time_until_deadline(invoice_workflow)
    return 'No deadline' unless has_sla_deadline?(invoice_workflow)

    deadline = Time.parse(invoice_workflow['sla_deadline'])
    duration = deadline - Time.current

    return 'Overdue' if duration < 0

    format_duration(duration)
  end

  def time_since_deadline(invoice_workflow)
    return 'No deadline' unless has_sla_deadline?(invoice_workflow)

    deadline = Time.parse(invoice_workflow['sla_deadline'])
    duration = Time.current - deadline

    return 'Not overdue' if duration < 0

    format_duration(duration)
  end

  def format_duration(duration_seconds)
    return '0 minutes' if duration_seconds <= 0

    days = duration_seconds / 1.day
    hours = (duration_seconds % 1.day) / 1.hour
    minutes = (duration_seconds % 1.hour) / 1.minute

    parts = []
    parts << "#{days.to_i} day#{'s' if days != 1}" if days >= 1
    parts << "#{hours.to_i} hour#{'s' if hours != 1}" if hours >= 1
    parts << "#{minutes.to_i} minute#{'s' if minutes != 1}" if minutes >= 1

    # If we have no parts, it's less than a minute
    return 'Less than 1 minute' if parts.empty?

    # Join parts with commas, but only show first two for readability
    parts.take(2).join(', ')
  end
end