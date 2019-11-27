require 'rails_helper'

describe Idv::ResendOtpController do
  let(:user) { build(:user) }

  let(:phone) { '+1 (225) 555-5000' }
  let(:user_phone_confirmation) { false }
  let(:delivery_method) { 'sms' }
  let(:user_phone_confirmation_session) do
    PhoneConfirmation::ConfirmationSession.start(
      phone: phone,
      delivery_method: delivery_method,
    )
  end

  before do
    stub_analytics
    allow(@analytics).to receive(:track_event)

    sign_in(user)
    stub_verify_steps_one_and_two(user)
    subject.idv_session.vendor_phone_confirmation = true
    subject.idv_session.user_phone_confirmation = user_phone_confirmation
    subject.idv_session.user_phone_confirmation_session = user_phone_confirmation_session
  end

  describe '#create' do
    context 'the user has not selected a delivery method' do
      let(:user_phone_confirmation_session) { nil }

      it 'redirects to otp delivery method selection' do
        post :create
        expect(response).to redirect_to(idv_phone_url)
      end
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'redirects to the review step' do
        post :create
        expect(response).to redirect_to(idv_review_path)
      end
    end

    it 'tracks an analytics event' do
      post :create

      expected_result = {
        success: true,
        errors: {},
        otp_delivery_preference: :sms,
        country_code: 'US',
        area_code: '225',
        rate_limit_exceeded: false,
      }

      expect(@analytics).to have_received(:track_event).with(
        Analytics::IDV_PHONE_CONFIRMATION_OTP_RESENT,
        expected_result,
      )
    end

    context 'twilio raises an exception' do
      let(:telephony_error_analytics_hash) do
        {
          error: 'Telephony::TelephonyError',
          message: 'error message',
          context: 'idv',
          country: 'US',
        }
      end
      let(:telephony_error) do
        Telephony::TelephonyError.new('error message')
      end

      before do
        stub_analytics
        allow(Telephony).to receive(:send_confirmation_otp).and_raise(telephony_error)
      end

      it 'tracks an analytics events' do
        expect(@analytics).to receive(:track_event).ordered.with(
          Analytics::TWILIO_PHONE_VALIDATION_FAILED, telephony_error_analytics_hash
        )

        post :create
      end
    end
  end
end
