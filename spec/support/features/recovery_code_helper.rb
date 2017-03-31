module RecoveryCodeHelper
  def reset_password_and_sign_back_in(user, password = 'a really long password')
    fill_in t('forms.passwords.edit.labels.password'), with: password
    click_button t('forms.passwords.edit.buttons.submit')
    fill_in_credentials_and_submit(user.email, password)
  end

  def recovery_code_from_pii(user, pii)
    profile = create(:profile, :active, :verified, user: user)
    pii_attrs = Pii::Attributes.new_from_hash(pii)
    user_access_key = user.unlock_user_access_key(user.password)
    recovery_code = profile.encrypt_pii(user_access_key, pii_attrs)
    profile.save!

    recovery_code
  end

  def trigger_reset_password_and_click_email_link(email)
    visit new_user_password_path
    fill_in 'Email', with: email
    click_button t('forms.buttons.continue')
    open_last_email
    click_email_link_matching(/reset_password_token/)
  end
end
