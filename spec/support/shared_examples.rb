# Brief §4: an enumerated or guessed ID for a record outside the current user's visibility
# scope must 404 -- never 403, never a data leak. `update` and `create` assert this inline
# per resource; this covers the four transition actions on the facility-scoped resources
# (Appointment, Admission), which all route through the same
# `Model.visible_to(current_user).find` lookup in `perform_transition`.
#
# The host context must provide: `doctor`, `password`, `collection_path`
# (e.g. "/api/v1/appointments"), and `inaccessible_record` (a persisted record at a
# facility `doctor` has no membership to).
RSpec.shared_examples "a facility-scoped transition action" do |action|
  it "returns not found when #{action} targets a record at an inaccessible facility" do
    sign_in_as(doctor, password: password)

    post "#{collection_path}/#{inaccessible_record.id}/#{action}", as: :json

    expect(response).to have_http_status(:not_found)
  end
end
