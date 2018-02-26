# -*- encoding : utf-8 -*-
module CsvImportDb

  def CsvImportDb.clean_value(value)
    cv = value.to_s.gsub("\"", "")
    cv
  end

  def CsvImportDb.clean_after_import(tname, path = "/tmp/")
    MorLog.my_debug("CSV clean_after_import #{tname}", 1)
    full_file_path = "#{path}#{tname}.csv"
    system("rm -f #{full_file_path}")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{tname};")
  end

  def CsvImportDb.log_swap(string)
    system("echo '#{Time.now.to_s(:db)} --- #{string}' >> /tmp/swap_log.txt")
    system("vmstat >> /tmp/swap_log.txt")
  end

  def CsvImportDb.head_of_file(path, n = 1)
    begin
      File.open(path) do |f|
        lines = []
        n.times do
          line = f.gets || break
          lines << line
        end
        if lines[0] and lines[0].size > 1000
          lines[0]= _('Line_seems_to_long_failed_to_determine_file_line_separator')
        end
        lines
      end
    rescue Exception => e
      MorLog.log_exception(e, Time.now.to_i, 'CsvImportDb.head_of_file', 'path')
      lines = ['ERROR : no file found']
    end
  end

  def CsvImportDb.save_file(id, file, path = "/tmp/")
    tname = "import_csv_#{id}_#{Time.now.to_i}"
    MorLog.my_debug("CSV save_file #{tname}", 1)
    CsvImportDb.log_swap('save_file')
    full_file_path = "#{path}#{tname}.csv"

    #create file
    File.open(full_file_path, 'wb:UTF-8') { |f| f.write(file.force_encoding('UTF-8')) }
    yy = YAML::load(File.open("#{Rails.root}/config/database.yml"))
    if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1 or (!yy['production']['host'].blank? and !yy['production']['host'].include?('localhost'))
      # move
      cp_cmd = "/usr/bin/scp root@127.0.0.1:#{full_file_path} root@#{yy['production']['host']}:#{full_file_path}"
      MorLog.my_debug(cp_cmd)
      system(cp_cmd)
    end

    MorLog.my_debug(tname)
    return tname
  end

  def CsvImportDb.load_csv_into_db(tname, sep, dec, fl, path = "/tmp/", options = {}, update_cols = true)
    MorLog.my_debug("CSV load_csv_into_db #{tname}", 1)
    CsvImportDb.log_swap('load')
    path = "/tmp/" if !path
    full_file_path = options[:xml] ? "#{path}#{tname}.xml" : "#{path}#{tname}.csv"

    #create table

    cols_size = options[:xml] ? 12 : fl.size
    cols = []

    strip_columns_array = []
    cols_size.times do |num|
      cols[num]= 'col_' + num.to_s + " VARCHAR(225) default NULL "
      strip_columns_array << "col_#{num} = TRIM(REPLACE(col_#{num},'\t',''))"
    end

    strip_columns = ""
    strip_columns << "SET " if cols_size > 0
    strip_columns << strip_columns_array.join(", ")
    incr_name = nil
    if options[:colums] and options[:colums].size > 0

      options[:colums].each do |col|
        z = col[:name].to_s + " " + col[:type].to_s
        z += " default " + col[:default].to_s if !col[:default].to_s.blank?
        z += col[:inscrement].to_s if !col[:inscrement].to_s.blank?
        incr_name = col[:name].to_s if !col[:inscrement].to_s.blank?
        cols << z
      end
    end

    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{tname};")
    sql = "CREATE TABLE #{tname} ("
    sql += cols.reject { |v| v.nil? or v.empty? }.join(" , ")
    sql += ", PRIMARY KEY  (#{incr_name})" if !incr_name.blank?
    sql += ") ENGINE=InnoDB DEFAULT CHARSET=utf8 ;"
    ActiveRecord::Base.connection.execute(sql)

    replace_tmp_table_headers(tname, cols_size) if update_cols

    if options[:xml]
      load = "LOAD XML INFILE '/home/kristina/fifty_rates.xml' IGNORE INTO TABLE #{tname} character set utf8"
      load+= ";"
    else
      load = "LOAD DATA LOCAL INFILE '#{full_file_path}' IGNORE INTO TABLE #{tname} character set utf8"
      load += " FIELDS TERMINATED BY '#{sep}' "
      load += " OPTIONALLY  ENCLOSED BY '\"' "
      load += " lines terminated by '\n' "
      load += strip_columns
      load += ";"
    end
    ActiveRecord::Base.connection.active?
    ActiveRecord::Base.connection.execute(load)
    MorLog.my_debug load
    return tname
  end

  def self.replace_tmp_table_headers(tname, colsize)
    sql = "UPDATE #{tname} SET "
    colsize.times do |index|
      sql << "col_#{index} = replace(col_#{index}, '\\r',''),"
    end
    sql.chop!
    sql << ';'
    ActiveRecord::Base.connection.execute(sql)
  end

  def self.create_index_for_prefix(tname, col_prefix)
    # we create index for prefix for faster mysql queries
    create_index = "CREATE INDEX index_prefix ON #{tname}(col_#{col_prefix});"
    ActiveRecord::Base.connection.execute(create_index)
  end
end
