# -*- encoding : utf-8 -*-
class Address < ActiveRecord::Base
  belongs_to :direction
  has_one :user
  has_one :cc_client

  attr_protected

  validate :address_before_save

  def address_before_save
    email = self.email.to_s
    email_not_empty = email.present?

    if email_not_empty && !Email.address_validation(email)
      errors.add(:email, _('Please_enter_correct_email'))
      return false
    end

    if email_not_empty
      dublicate, dublicate_email = no_dublicate_emails
        unless dublicate
          errors.add(:email, _('email_space') + dublicate_email + _('Is_already_used'))
        return false
      end
    end
  end

  def no_dublicate_emails
    unless allow_duplicate_emails?
      not_self = "AND id != '#{self.id}'" unless id.nil?
      addresses_all = Address.where("email != 'null' #{not_self}").pluck(:email)
      emails = email.split(';').reject(&:blank?)
      addressses = []
        addresses_all.each do |address|
          addressses << address.downcase.split(';').reject(&:blank?)
        end

        # All warning balance emails
        not_self_user = "AND id != '#{self.user.id}'" unless self.user.nil?
        warning_emails = User.where("warning_balance_email != 'null' #{not_self_user}").pluck(:warning_balance_email)
        warning_emails.each do |emails|
         addressses << emails.downcase.split(';').reject(&:blank?)
        end

        splitted_emails = addressses.flatten.collect(&:strip)
        emails.each do |mail|
          mail.gsub!(/\s+/, '')
          if splitted_emails.include?(mail.downcase)
            return false, mail
          end
        end
      end
    true
  end

  private

  def allow_duplicate_emails?
    Confline.get_value('allow_identical_email_addresses_to_different_users', 0).to_i == 1
  end
end
