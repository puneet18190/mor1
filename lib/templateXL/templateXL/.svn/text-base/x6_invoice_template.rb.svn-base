require 'template'
module TemplateXL
  class X6InvoiceTemplate < Template
    attr_accessor :invoice
    attr_accessor :invoicedetails
    attr_accessor :workbook
    attr_accessor :users

    # Parses the XLSX template and assigns it to @workbook
    def initialize(template_path, save_path, inv_user_owner_id, number_precision = 0)
      super(template_path, save_path, inv_user_owner_id, number_precision)
      @lines = '@invoicedetails'
      Invoicedetail.reset_destination_number
    end

    private

    # The confline settings are used as user's input for the confline
    # For example, if we have a confline named 'Cell_invoice_exchange_rate'
    # It will assign the value returned by invoice.exchange_rate to Confline's value
    # That could be for example: 'A2'
    # The method below collects Cell_ conflines, and edits them.
    # For example: Cell_invoice_exchange_rate becomes 'invoice.exchange_rate'

    def initialize_coordinates
      invoice_template_coordinates = Confline.where("name LIKE 'Cell_x6_inv_%' AND owner_id = ?", @inv_user_owner_id).all

      unless invoice_template_coordinates.blank?
        invoice_template_coordinates.each do |confline|
          key = confline.name
          key.sub!('Cell_', '')
          coordinates = RubyXL::Reference.ref2ind(confline.value.to_s)
          if key['x6_inv_details']
            key.sub!('x6_inv_details_', 'invoicedetails.')
            @lines_details[key] = coordinates
          elsif key['x6_inv_user']
            key.sub!('x6_inv_user_', 'users.')
            @user_details[key] = coordinates
          else
            key.sub!('x6_inv_', 'invoice.')
            @details[key] = coordinates
          end
        end
      end
    end
  end
end