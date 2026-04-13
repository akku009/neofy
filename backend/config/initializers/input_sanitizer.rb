# Shared input sanitization constants and helpers.
# Applied to user-provided strings before they hit the DB or templates.
module InputSanitizer
  MAX_STRING_LENGTH    = 10_000   # Maximum allowed string field length
  MAX_NOTE_LENGTH      = 5_000    # Order notes
  MAX_DESCRIPTION_LENGTH = 50_000 # Product descriptions

  # Strips null bytes and limits length to prevent DB/template injection.
  def self.sanitize(str, max_length: MAX_STRING_LENGTH)
    return str unless str.is_a?(String)
    str.delete("\u0000").truncate(max_length, omission: "")
  end
end
