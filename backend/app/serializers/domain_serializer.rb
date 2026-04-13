class DomainSerializer < ActiveModel::Serializer
  attributes :id,
             :store_id,
             :domain,
             :verified,
             :primary,
             :verified_at,
             :verification_instructions,
             :created_at,
             :updated_at

  # Expose the TXT record instructions only for unverified domains.
  # Once verified, these are no longer needed and should not clutter the response.
  def verification_instructions
    return nil if object.verified?

    {
      record_type:  "TXT",
      record_name:  object.txt_record_name,
      record_value: object.txt_record_value,
      instructions: "Add this TXT record to your DNS provider, then call the verify endpoint. " \
                    "DNS changes can take up to 48 hours to propagate."
    }
  end
end
