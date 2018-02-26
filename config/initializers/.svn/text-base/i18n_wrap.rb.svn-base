# AS: development sees untranslated strings
def _(str, *args)
  hash = {}
  unless args.blank?
    keys = [:s]
    args_size = args.size - 1
    args_size.times {|index| keys << "s#{index.next}".to_sym}
    hash = Hash[keys.zip(args)]
  end

  current_locale = I18n.locale.to_s
  begin
    hash[:raise] = true
    translation = Rails.env == 'development' ? I18n.t("mor.#{str}", hash) : I18n.t("mor.#{str}", hash.merge(default: str))
  rescue I18n::MissingTranslationData
    I18n.locale = 'en'
    hash[:raise] = false
    translation = Rails.env == 'development' ? I18n.t("mor.#{str}", hash) : I18n.t("mor.#{str}", hash.merge(default: str))
    I18n.locale = current_locale
  end

  return translation
end
