require "test_helper"

class WorkflowHelperTest < ActionView::TestCase
  include WorkflowHelper

  setup do
    @current_time = Time.parse("2024-01-15 10:00:00 UTC")
    Time.stubs(:current).returns(@current_time)

    @workflow_with_sla = {
      'entered_current_state_at' => '2024-01-15 08:00:00 UTC',
      'sla_deadline' => '2024-01-15 12:00:00 UTC',
      'is_overdue' => false
    }

    @overdue_workflow = {
      'entered_current_state_at' => '2024-01-14 08:00:00 UTC',
      'sla_deadline' => '2024-01-15 09:00:00 UTC',
      'is_overdue' => true
    }

    @warning_workflow = {
      'entered_current_state_at' => '2024-01-15 08:00:00 UTC',
      'sla_deadline' => '2024-01-15 10:30:00 UTC', # 30 minutes from now
      'is_overdue' => false
    }

    @workflow_without_sla = {
      'entered_current_state_at' => '2024-01-15 08:00:00 UTC'
    }
  end

  test "sla_status_class returns correct class for overdue workflow" do
    assert_equal 'text-red-600 bg-red-100', sla_status_class(@overdue_workflow)
  end

  test "sla_status_class returns correct class for warning workflow" do
    assert_equal 'text-yellow-600 bg-yellow-100', sla_status_class(@warning_workflow)
  end

  test "sla_status_class returns correct class for normal workflow" do
    assert_equal 'text-green-600 bg-green-100', sla_status_class(@workflow_with_sla)
  end

  test "sla_status_class returns empty string for workflow without SLA" do
    assert_equal '', sla_status_class(@workflow_without_sla)
  end

  test "sla_status_class returns empty string for nil workflow" do
    assert_equal '', sla_status_class(nil)
  end

  test "sla_status_text returns overdue message for overdue workflow" do
    result = sla_status_text(@overdue_workflow)
    assert_includes result, "Overdue by"
    assert_includes result, "1 hour"
  end

  test "sla_status_text returns due in message for warning workflow" do
    result = sla_status_text(@warning_workflow)
    assert_includes result, "Due in"
    assert_includes result, "30 minute"
  end

  test "sla_status_text returns due in message for normal workflow" do
    result = sla_status_text(@workflow_with_sla)
    assert_includes result, "Due in"
    assert_includes result, "2 hour"
  end

  test "sla_status_text returns No SLA for workflow without deadline" do
    assert_equal 'No SLA', sla_status_text(@workflow_without_sla)
  end

  test "sla_icon returns correct icon for different states" do
    assert_equal 'exclamation-triangle', sla_icon(@overdue_workflow)
    assert_equal 'exclamation-circle', sla_icon(@warning_workflow)
    assert_equal 'clock', sla_icon(@workflow_with_sla)
    assert_equal 'clock', sla_icon(@workflow_without_sla)
  end

  test "time_in_current_state calculates duration correctly" do
    result = time_in_current_state(@workflow_with_sla)
    assert_equal "2 hours", result
  end

  test "time_in_current_state returns Unknown for workflow without timestamp" do
    workflow_without_timestamp = {}
    assert_equal 'Unknown', time_in_current_state(workflow_without_timestamp)
  end

  test "sla_progress_percentage calculates correct percentage" do
    # Entered at 08:00, deadline at 12:00 (4 hours total)
    # Current time 10:00 (2 hours elapsed)
    # Progress should be 50%
    assert_equal 50, sla_progress_percentage(@workflow_with_sla)
  end

  test "sla_progress_percentage returns 100 for overdue workflow" do
    assert_equal 100, sla_progress_percentage(@overdue_workflow)
  end

  test "sla_progress_percentage returns 0 for workflow without SLA" do
    assert_equal 0, sla_progress_percentage(@workflow_without_sla)
  end

  test "sla_deadline_formatted formats deadline correctly" do
    result = sla_deadline_formatted(@workflow_with_sla)
    assert_equal "Jan 15, 2024 at 12:00 PM", result
  end

  test "sla_deadline_formatted returns nil for workflow without SLA" do
    assert_nil sla_deadline_formatted(@workflow_without_sla)
  end

  test "format_duration handles various durations" do
    assert_equal "1 day, 2 hours", format_duration(1.day + 2.hours)
    assert_equal "2 hours, 30 minutes", format_duration(2.hours + 30.minutes)
    assert_equal "45 minutes", format_duration(45.minutes)
    assert_equal "Less than 1 minute", format_duration(30.seconds)
    assert_equal "0 minutes", format_duration(-10.minutes)
  end

  test "format_duration handles singular vs plural correctly" do
    assert_equal "1 day", format_duration(1.day)
    assert_equal "2 days", format_duration(2.days)
    assert_equal "1 hour", format_duration(1.hour)
    assert_equal "2 hours", format_duration(2.hours)
    assert_equal "1 minute", format_duration(1.minute)
    assert_equal "2 minutes", format_duration(2.minutes)
  end

  test "private methods work correctly" do
    # Test sla_overdue?
    assert send(:sla_overdue?, @overdue_workflow)
    assert_not send(:sla_overdue?, @workflow_with_sla)

    # Test sla_warning?
    assert send(:sla_warning?, @warning_workflow)
    assert_not send(:sla_warning?, @workflow_with_sla)

    # Test has_sla_deadline?
    assert send(:has_sla_deadline?, @workflow_with_sla)
    assert_not send(:has_sla_deadline?, @workflow_without_sla)
  end

  test "time calculations handle edge cases" do
    # Test time_until_deadline for overdue
    result = send(:time_until_deadline, @overdue_workflow)
    assert_equal 'Overdue', result

    # Test time_since_deadline for not overdue
    result = send(:time_since_deadline, @workflow_with_sla)
    assert_equal 'Not overdue', result
  end

  test "handles different warning thresholds" do
    # Create workflow that's within 2 hours of deadline
    workflow_near_deadline = {
      'entered_current_state_at' => '2024-01-15 08:00:00 UTC',
      'sla_deadline' => '2024-01-15 11:30:00 UTC', # 1.5 hours from current time
      'is_overdue' => false
    }

    assert send(:sla_warning?, workflow_near_deadline)
    assert_equal 'text-yellow-600 bg-yellow-100', sla_status_class(workflow_near_deadline)
  end
end