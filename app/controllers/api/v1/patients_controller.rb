class Api::V1::PatientsController < Api::V1::BaseController
  def index
    patients = Patient.visible_to(current_user)
    render json: { patients: PatientSerializer.render_collection(patients) }
  end

  def create
    patient = current_user.organization.patients.build(patient_params)

    if patient.save
      render json: { patient: PatientSerializer.new(patient).as_json }, status: :created
    else
      render json: { errors: patient.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    patient = Patient.visible_to(current_user).find(params[:id])

    if patient.update(patient_params)
      render json: { patient: PatientSerializer.new(patient).as_json }
    else
      render json: { errors: patient.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  # Deliberately not role-gated to org_admin, unlike Facility/User create/update -- brief §7's
  # two-step booking flow ("find or create the patient first") is core day-to-day front-desk/
  # clinical work, not an org-structure administrative change, so any authenticated staff member
  # (doctor, receptionist, org_admin) can create/update patient records. mrn is never permitted
  # here -- it's auto-generated (Patient#generate_mrn) and never client-settable.
  def patient_params
    params.require(:patient).permit(:first_name, :last_name, :date_of_birth, :gender, :phone_number, :email)
  end
end
