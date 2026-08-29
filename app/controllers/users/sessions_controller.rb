class Users::SessionsController < Devise::SessionsController
  private

  def respond_with(resource, _opts = {})
    assign_sole_accessible_facility(resource)
    render json: { user: UserSerializer.new(resource).as_json }, status: :ok
  end

  def respond_to_on_destroy(non_navigational_status: :no_content)
    head non_navigational_status
  end

  # Brief §5: on login, auto-set the current facility only in the unambiguous case -- the user
  # has none yet and exactly one accessible facility. Two or more (or zero) and they choose
  # later via PATCH /api/v1/me. update_column: this is a derived convenience, not a user edit,
  # so it deliberately doesn't bump updated_at or run callbacks.
  def assign_sole_accessible_facility(user)
    return if user.default_facility_id.present?

    facilities = user.accessible_facilities.to_a
    user.update_column(:default_facility_id, facilities.first.id) if facilities.one?
  end
end
