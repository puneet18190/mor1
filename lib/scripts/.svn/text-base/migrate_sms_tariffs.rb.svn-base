module SmsTariffsMigrator
  # The module helps to map the SMS Tariffs and Rates to voice Tariffs.
  # This functionality has been introduced as a helper to reduce the side effects from #12680.
  def self.migrate
    MorLog.my_debug('-----------------------------------------------------')
    MorLog.my_debug("[#{Time.now}] SMS Tariffs migration has been started")

    # Not possible to migrate
    return -1 unless Confline.get_value('SMS_Tariffs_migrated').blank?

    # Get all SMS Tariffs
    sms_tariffs = SmsTariff.all
    # Nothing to migrate
    unless sms_tariffs.present?
      MorLog.my_debug('No SMS Tariffs to migrate')
      return 0
    end

    # Prepare and initialize a hash for mappings: {old_id: new_id}
    mapped_ids = Hash[sms_tariffs.map { |tariff| [tariff.id, nil] }]

    # Create a corresponding Tariff from an SMS Tariff and map its id
    sms_tariffs.each do |sms_tariff|

      # Generate a unique name
      sms_tariff.name << ' SMS'
      index = 0
      new_name = sms_tariff.name
      while Tariff.where(name: sms_tariff.name, owner_id: sms_tariff.owner_id).present? do
        sms_tariff.name = "#{new_name} #{index += 1}"
      end

      new_tariff = Tariff.create(name: sms_tariff.name, purpose: sms_tariff.tariff_type == 'user' ? 'user_wholesale' : 'provider',
        owner_id: sms_tariff.owner_id, currency: sms_tariff.currency)
      mapped_ids[sms_tariff.id] = new_tariff.try(:id)
    end
    mapped_ids.reject! { |key, value| value.blank? }

    # Create temporary table for storing the migration data
    ActiveRecord::Base.connection.execute('
      CREATE TEMPORARY TABLE IF NOT EXISTS sms_rates_migration AS (
        SELECT sms_tariff_id AS tariff_id, prefix, price AS rate
          FROM sms_rates
      )')

    # Remap Tariff ids for Users and Providers
    MorLog.my_debug("[#{Time.now}] SMS Provider and SMS User Tariffs remapping has been started")
    mapped_ids.each do |key, value|
      ActiveRecord::Base.connection.execute("
        UPDATE sms_rates_migration SET tariff_id = #{value}
          WHERE tariff_id = #{key}")
      ActiveRecord::Base.connection.execute("
        UPDATE sms_providers SET tariff_id = #{value}
          WHERE tariff_id = #{key}")
      ActiveRecord::Base.connection.execute("
        UPDATE users SET sms_tariff_id = #{value}
          WHERE sms_tariff_id = #{key}")
    end

    MorLog.my_debug("[#{Time.now}] SMS Provider and SMS User Tariffs remapping has been completed")
    MorLog.my_debug("Number of SMS Tariffs migrated: #{mapped_ids.size}")

    MorLog.my_debug("[#{Time.now}] SMS Rates migration has been started")

    # Get the ids of the previous Rates

    # Store the remapped Rates on a Rates table
    ActiveRecord::Base.connection.execute('
      INSERT INTO rates
      (tariff_id, prefix, destination_id, destinationgroup_id, ghost_min_perc)
      SELECT tariff_id, sms_rates_migration.prefix, destinations.id,
        destinations.destinationgroup_id, rate
      FROM sms_rates_migration
        JOIN destinations
          ON sms_rates_migration.prefix = destinations.prefix')

    new_tariff_ids = mapped_ids.values.join(',')

    unless new_tariff_ids.blank?
      # Store the Rate details for each new Rate
      ActiveRecord::Base.connection.execute("
        INSERT INTO ratedetails
        (rate_id, rate)
        SELECT id, ghost_min_perc
        FROM rates
        WHERE tariff_id IN (#{new_tariff_ids})")

      MorLog.my_debug("[#{Time.now}] SMS Rates migration has been completed")

      # Clean the workspace
      ActiveRecord::Base.connection.execute("
        UPDATE rates
        SET ghost_min_perc = 0
        WHERE tariff_id IN (#{new_tariff_ids})")
    end

    ActiveRecord::Base.connection.execute('DROP TABLE sms_rates_migration')

    MorLog.my_debug("[#{Time.now}] Migration has been completed")
    Confline.set_value('SMS_Tariffs_migrated', '1')

    return mapped_ids.size
  end
end
