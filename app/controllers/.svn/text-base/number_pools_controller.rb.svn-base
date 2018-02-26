# -*- encoding : utf-8 -*-
# Number Pools are used for Device or Provider as CallerIDs.
class NumberPoolsController < ApplicationController

  layout 'callc'

  before_filter :access_denied, :if => lambda { !admin? && !reseller? }
  before_filter :check_post_method, only: [:pool_create, :pool_update, :pool_destroy, :number_create, :number_destroy]
  before_filter :find_number_pool, only: [:pool_edit, :pool_update, :pool_destroy, :number_list, :number_import, :destroy_all_numbers, :bad_numbers]
  before_filter :find_number, only: [:number_destroy]

  # ------ Number Pools Begin ------ #
  def pool_list
    @page_title = _('Number_Pools')
    @page_icon = 'number_pool.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"

    session[:number_pool_list] ? @options = session[:number_pool_list] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "id" if !@options[:order_by])

    order_by = NumberPool.number_pools_order_by(@options)

    # page params
    @total_pools_size = NumberPool.count
    @fpage, @total_pages, @options = Application.pages_validator(session, @options, @total_pools_size)
    @page = @options[:page]

    @number_pools = NumberPool.select("number_pools.*, COUNT(n.id) AS num")
                              .joins("LEFT JOIN numbers n ON (n.number_pool_id = number_pools.id)")
                              .where(owner_id: current_user.id)
                              .group("number_pools.id")
                              .order(order_by)
                              .limit("#{@fpage}, #{session[:items_per_page].to_i}").all


    session[:number_pool_list] = @options
  end

  def pool_new
    @page_title = _('New_number_pool')
    @page_icon = "add.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"
  end

  def pool_create
    @number_pool = NumberPool.new(params[:number_pool].merge!(owner_id: current_user.id))
    if @number_pool.save
      flash[:status] = _('number_pool_successfully_created')
      redirect_to action: 'pool_list' and return false
    else
      flash_errors_for(_('number_pool_was_not_created'), @number_pool)
      render :pool_new
    end
  end

  def pool_edit
    @page_title = _('number_pool_edit')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"
  end

  def pool_update
    @number_pool.attributes = @number_pool.attributes.merge(params[:number_pool])
    if @number_pool.save
      flash[:status] = _('number_pool_successfully_updated')
      redirect_to action: 'pool_list' and return false
    else
      flash_errors_for(_('number_pool_was_not_updated'), @number_pool)
      render :pool_edit
    end
  end

  def pool_destroy
    if @number_pool.destroy
      flash[:status] = _('number_pool_successfully_deleted')
      redirect_to(action: :pool_list) && (return false)
    else
      flash_errors_for(_('number_pool_was_not_deleted'), @number_pool)
      redirect_to(action: :pool_list) && (return false)
    end
  end

  # ------ Number Pools End ------ #

  # ------ Numbers Start ------ #

  def number_list

    @page_title = _('Number_Pools')
    @page_icon = 'details.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"

    number_pool_owner = NumberPool.where(id: params[:id]).first.owner_id
    if number_pool_owner != current_user_id
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    session[:number_list] ? @options = session[:number_list] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "id" if !@options[:order_by])

    order_by = Number.numbers_order_by(@options)
    number_wcard = params[:s_number] || @options[:s_number]
    number_wcard = '' if params[:clear]

    @numbers = @number_pool.numbers.retrieve(number_wcard, order_by)
    @total_numbers_size = @numbers.size

    # page params
    page_size = session[:items_per_page].to_i
    @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
    @total_pages = (@total_numbers_size / page_size.to_f).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    @page = @options[:page]
    @fpage = ((@options[:page] -1) * page_size).to_i

    @numbers = @numbers.limit(page_size).offset(@fpage)
    @options[:s_number] = number_wcard
    session[:number_list] = @options
  end

  def number_destroy
    if @number.destroy
      flash[:status] = _('number_successfully_deleted')
      redirect_to action: 'number_list', id: @number.number_pool_id and return false
    else
      flash_errors_for(_('number_was_not_deleted'), @number_pool)
      redirect_to action: 'number_list', id: @number.number_pool_id and return false
    end
  end

  def destroy_all_numbers
    @number_pool.numbers.where("").delete_all
    flash[:status] = _('all_numbers_successfully_deleted')
    redirect_to action: 'number_list', id: @number_pool.id and return false
  end

  def number_import
    @page_title = _('Number_import')
    @page_icon = 'details.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"

    @step = 1
    @step = params[:step].to_i if params[:step]
    number_pool_id = @number_pool.id

    if @step == 2
      if params[:file]
        @file = params[:file]
        if @file.size > 0

          if !@file.respond_to?(:original_filename) || !@file.respond_to?(:read) || !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to(action: 'number_import', id: @campaign.id, step: '0') && (return false)
          end

          @imported_numbers = 0
          numbers_to_import = 0
          @bad_numbers_quantity = 0
          array_for_sql = []
          bad_numbers = []

          begin
            @file.rewind
            file = @file.read
            session[:file_size] = file.size

            # Creating temp table.
            ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS temp_numbers_#{number_pool_id}")
            ActiveRecord::Base.connection.execute("CREATE TEMPORARY TABLE temp_numbers_#{number_pool_id} (number VARCHAR(255), number_pool_id int(11))")
            file.each_line { |file_line|
              if is_number_or_prefix?(file_line.to_s.strip.chomp)
                numbers_to_import += 1
                array_for_sql << "('#{file_line.strip.chomp}', #{number_pool_id})"
              elsif not file_line.blank?
                line = file_line.to_s.strip.force_encoding('UTF-8')
                if line.valid_encoding?
                  @bad_numbers_quantity += 1
                  bad_numbers << line
                end
              end
            }

            @total_numbers = numbers_to_import + @bad_numbers_quantity

            # file for bad numbers
            File.open("/tmp/bad_numbers.txt", "w+") do |file|
              file.write(bad_numbers.join("\n"))
            end
            `chmod 777 /tmp/bad_numbers.txt`
            `rm -rf /tmp/mor/existing_numbers_in_db_#{number_pool_id}.txt`
            `rm -rf /tmp/mor/duplicate_numbers_in_file_#{number_pool_id}.txt`

            # Inserting numbers into temp table.
            sql = "INSERT INTO temp_numbers_#{number_pool_id} (number, number_pool_id) VALUES #{array_for_sql.join(", ")}"
            ActiveRecord::Base.connection.execute(sql) if numbers_to_import > 0

            # Existing numbers in db.
            existing_numbers_query = "SELECT temp_numbers_#{number_pool_id}.number
                                      INTO OUTFILE '/tmp/mor/existing_numbers_in_db_#{number_pool_id}.txt'
                                      FIELDS TERMINATED BY ','
                                      LINES TERMINATED BY '\n'
                                      FROM temp_numbers_#{number_pool_id}
                                      LEFT JOIN numbers ON (numbers.number = temp_numbers_#{number_pool_id}.number AND numbers.number_pool_id = #{number_pool_id})
                                      WHERE numbers.number IS NOT NULL"
            ActiveRecord::Base.connection.execute(existing_numbers_query)

            # Duplicate numbers with their count.
            duplicate_numbers_in_file = "SELECT number
                                          INTO OUTFILE '/tmp/mor/duplicate_numbers_in_file_#{number_pool_id}.txt'
                                          FIELDS TERMINATED BY ','
                                          LINES TERMINATED BY '\n'
                                          FROM temp_numbers_#{number_pool_id}
                                          GROUP BY number HAVING COUNT(number) > 1"
            ActiveRecord::Base.connection.execute(duplicate_numbers_in_file)

            # Successfully imported numbers.
            imported_numbers_count_query = "SELECT COUNT(DISTINCT temp_numbers_#{number_pool_id}.number) AS imported_numbers
                                            FROM temp_numbers_#{number_pool_id}
                                            LEFT JOIN numbers ON (numbers.number = temp_numbers_#{number_pool_id}.number AND numbers.number_pool_id = #{number_pool_id})
                                            WHERE numbers.number IS NULL"

            @imported_numbers = ActiveRecord::Base.connection.select_value(imported_numbers_count_query)

            # Inserting unique numbers into numbers table.
            inserting_query = "INSERT INTO numbers(number, number_pool_id)
                                                  (SELECT DISTINCT temp_numbers_#{number_pool_id}.number,
                                                                   temp_numbers_#{number_pool_id}.number_pool_id
                                                   FROM temp_numbers_#{number_pool_id}
                                                   LEFT JOIN numbers ON (numbers.number = temp_numbers_#{number_pool_id}.number AND numbers.number_pool_id = #{number_pool_id})
                                                   WHERE numbers.number IS NULL)"
            ActiveRecord::Base.connection.execute(inserting_query)

            if @total_numbers == @imported_numbers
              flash[:status] = _('Numbers_successfully_imported')
            else
              flash[:status] = _('M_out_of_n_numbers_imported', @imported_numbers, @total_numbers)
              @bad_numbers_quantity =  @total_numbers - @imported_numbers
            end
          end
        else
          flash[:notice] = _('Please_select_file')
          redirect_to(action: 'number_import', id: number_pool_id) && (return false)
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: 'number_import', id: number_pool_id) && (return false)
      end
    end
  end

  def bad_numbers
    @page_title = _('Bad_numbers_from_file')
    @page_icon = 'details.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/Number_Pool"

    @rows = []
    @dup_numbers = []
    number_pool_id = @number_pool.id
    File.open("/tmp/bad_numbers.txt", "r").each_line do |f|
      @rows << f
    end
    `cat /tmp/mor/duplicate_numbers_in_file_#{number_pool_id}.txt /tmp/mor/existing_numbers_in_db_#{number_pool_id}.txt | sort | uniq > /tmp/mor/dup_in_#{number_pool_id}.txt`
    File.open("/tmp/mor/dup_in_#{number_pool_id}.txt", "r").each_line do |f|
      @dup_numbers << f
    end
  end


  # ------ Numbers End ------ #

  private

  def find_number_pool
    @number_pool = NumberPool.where(id: params[:id]).first
    unless @number_pool
      flash[:notice] = _('number_pool_was_not_found')
      redirect_to action: 'pool_list' and return false
    end
  end

  def find_number
    @number = Number.where(id: params[:id]).first
    unless @number
      flash[:notice] = _('number_was_not_found')
      redirect_to action: 'number_list' and return false
    end
  end
end
