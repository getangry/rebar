# Disable host authorization in test environment
# This is needed for Rswag/Swagger API tests which may use various host headers

Rails.application.configure do
  if Rails.env.test?
    config.hosts = nil
  end
end
