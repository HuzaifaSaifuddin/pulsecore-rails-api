class Users::PasswordsController < Devise::PasswordsController
  # POST /users/password -- request reset instructions by email
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)

    if successfully_sent?(resource)
      render json: { message: "If that email is registered, password reset instructions have been sent." }
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /users/password -- submit a new password with the emailed token
  def update
    self.resource = resource_class.reset_password_by_token(resource_params)

    if resource.errors.empty?
      resource.unlock_access! if unlockable?(resource)
      if sign_in_after_reset_password?
        resource.after_database_authentication
        sign_in(resource_name, resource)
      end
      render json: { user: UserSerializer.new(resource).as_json }
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_content
    end
  end
end
