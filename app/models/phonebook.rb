# -*- encoding : utf-8 -*-
# Organized list of known CallerIDs
class Phonebook < ActiveRecord::Base
  belongs_to :user

  attr_protected

  validates :name, presence: { message: _('speeddial_name_must_be_provided') }
  validates :number, presence: { message: _('record_number_should_have_at_least_one_digit') }
  validates_length_of :speeddial, minimum: 2, message: _('Speeddial_can_only_be_2_and_more_digits')
  validates_format_of :number, with: /\A\d+\Z/, message: _('Record_number_must_be_numeric'), if: :number?
  validates_format_of :speeddial, with: /\A\d+\Z/, message: _('Speeddial_must_be_numeric'), if: :speeddial?

  before_save :validate_speeddial_uniqueness

  def self.user_phonebooks(user)
    where(user_id: [0, user.id], card_id: 0).order(:name)
  end

  private

  # PhoneBooks speed dial must be unique for each user, but we have to remember that admin's phonebooks are global, so
  #   setting unique on user_id and speed dial is not an option - speed dial has to e unique for phonebooks user and
  #   for admin.
  def validate_speeddial_uniqueness
    condition = "speeddial = '#{self.speeddial}'"
    if self.user.is_admin?
      if self.id
        condition += " AND id != #{self.id} "
      end
    else
      condition += " AND user_id IN ( #{user.id})"
      if self.id
        condition += " AND id != #{self.id}"
      end
    end
    condition += " AND card_id = #{self.card_id}"
    count = Phonebook.where(condition).size
    if count == 0
      return true
    else
      errors.add(:speeddial, _('Speed_dial_must_be_unique'))
      return false
    end
  end
end
