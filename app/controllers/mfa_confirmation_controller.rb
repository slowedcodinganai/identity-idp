class MfaConfirmationController < ApplicationController
  include MfaSetupConcern
  before_action :confirm_two_factor_authenticated, except: [:show]

  def show
    @presenter = MfaConfirmationShowPresenter.new(
      current_user: current_user,
      next_path: next_path,
      final_path: after_mfa_setup_path,
      suggest_second_mfa: check_if_select_mfa_needed?,
    )
  end

  def skip
    user_session.delete(:mfa_selections)
    user_session.delete(:next_mfa_selection_choice)
    redirect_to after_mfa_setup_path
  end

  def new
    session[:password_attempts] ||= 0
  end

  def create
    if current_user.valid_password?(password)
      handle_valid_password
    else
      handle_invalid_password
    end
  end

  private

  def password
    params.require(:user)[:password]
  end

  def next_mfa_selection_choice
    params[:next_setup_choice] ||
      user_session[:next_mfa_selection_choice]
  end

  def next_path
    return second_mfa_setup_path if check_if_select_mfa_needed?
    confirmation_path(next_mfa_selection_choice)
  end

  def check_if_select_mfa_needed?
    suggest_second_mfa? && current_mfa_selection_count == 1
  end

  def handle_valid_password
    if current_user.auth_app_configurations.any?
      redirect_to login_two_factor_authenticator_url(reauthn: true)
    else
      redirect_to user_two_factor_authentication_url(reauthn: true)
    end
    session[:password_attempts] = 0
    user_session[:current_password_required] = false
  end

  def handle_invalid_password
    session[:password_attempts] = session[:password_attempts].to_i + 1

    if session[:password_attempts] < IdentityConfig.store.password_max_attempts
      flash[:error] = t('errors.confirm_password_incorrect')
      redirect_to user_password_confirm_url
    else
      handle_max_password_attempts_reached
    end
  end

  def handle_max_password_attempts_reached
    analytics.password_max_attempts
    sign_out
    redirect_to root_url, flash: { error: t('errors.max_password_attempts_reached') }
  end
end
