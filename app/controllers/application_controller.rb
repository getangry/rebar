class ApplicationController < ActionController::API
  # Graceful error handling for API responses
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_bad_request
  rescue_from ForbiddenError, with: :handle_forbidden

  private

  def handle_standard_error(exception)
    Rails.logger.error("#{exception.class}: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))

    render json: {
      error: "Internal server error",
      message: exception.message
    }, status: :internal_server_error
  end

  def handle_not_found(exception)
    render json: {
      error: "Not found",
      message: exception.message
    }, status: :not_found
  end

  def handle_bad_request(exception)
    render json: {
      error: "Bad request",
      message: exception.message
    }, status: :bad_request
  end

  def handle_forbidden(exception)
    render json: {
      error: "Forbidden",
      message: exception.message
    }, status: :forbidden
  end
end
