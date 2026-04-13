require "cgi"

module Theme
  # Simplified Liquid-like template engine.
  #
  # Supports:
  #   {{ variable }}               — outputs the value of a variable (HTML-escaped)
  #   {{ object.attribute }}       — dot-notation access
  #   {% for item in collection %} — iterates over an array
  #   {% endfor %}
  #   {% if condition %}           — conditional rendering
  #   {% endif %}
  #   {% if !condition %}          — negated conditional
  #   {% if a == "b" %}            — equality comparison
  #
  # Security:
  #   - No eval, no send, no method calls on Ruby objects
  #   - All variable output is HTML-escaped via CGI.escapeHTML
  #   - Only Hash-based context is accepted (ActiveRecord objects converted via to_template_hash)
  #
  class RenderTemplate < ApplicationService
    # Matches {{ ... }} and {% ... %} blocks; captures separators for splitting
    TOKENIZE_REGEX  = /(\{\{.*?\}\}|\{%.*?%\})/m
    VARIABLE_REGEX  = /\A\{\{\s*(.+?)\s*\}\}\z/m
    TAG_REGEX       = /\A\{%\s*(.+?)\s*%\}\z/m

    def initialize(template:, context: {})
      @template = template.to_s
      @context  = deep_stringify(context)
    end

    def call
      tokens        = tokenize(@template)
      output, _idx  = render_block(tokens, 0, @context)
      success(output)
    rescue => e
      Rails.logger.error("[Theme::RenderTemplate] #{e.class}: #{e.message}")
      failure("Template render error: #{e.message}")
    end

    private

    # ── Tokenizer ──────────────────────────────────────────────────────────────
    # Splits the template source into a flat array of text nodes, {{ }} nodes,
    # and {% %} nodes.
    def tokenize(source)
      source.split(TOKENIZE_REGEX).reject(&:empty?)
    end

    # ── Block renderer ─────────────────────────────────────────────────────────
    # Renders tokens sequentially from start_idx, returning [output, next_idx].
    # Stops when it reaches the end of the token array.
    def render_block(tokens, start_idx, context)
      output = +""
      idx    = start_idx

      while idx < tokens.size
        token = tokens[idx]

        if (m = token.match(VARIABLE_REGEX))
          output << render_variable(m[1].strip, context)
          idx += 1

        elsif (m = token.match(TAG_REGEX))
          keyword = m[1].strip.split(/\s+/).first

          case keyword
          when "for"
            output, idx = handle_for(tokens, idx, context, output)
          when "if"
            output, idx = handle_if(tokens, idx, context, output)
          else
            # endfor, endif, unknown tags — just skip past them
            idx += 1
          end

        else
          output << token
          idx += 1
        end
      end

      [output, idx]
    end

    # ── {% for var in collection %} ────────────────────────────────────────────
    def handle_for(tokens, idx, context, output)
      parts    = tokens[idx].match(TAG_REGEX)[1].strip.split(/\s+/)
      var_name = parts[1]      # e.g. "product"
      coll_key = parts[3]      # e.g. "products"

      end_idx      = find_closing_tag(tokens, idx, "for", "endfor")
      inner_tokens = tokens[(idx + 1)...end_idx]
      collection   = resolve(coll_key, context)

      result = +""
      if collection.is_a?(Array)
        collection.each do |item|
          item_ctx        = context.merge(var_name => to_context_hash(item))
          item_out, _     = render_block(inner_tokens, 0, item_ctx)
          result << item_out
        end
      end

      [output + result, end_idx + 1]
    end

    # ── {% if condition %} ─────────────────────────────────────────────────────
    def handle_if(tokens, idx, context, output)
      condition    = tokens[idx].match(TAG_REGEX)[1].strip.sub(/\Aif\s+/, "")
      end_idx      = find_closing_tag(tokens, idx, "if", "endif")
      inner_tokens = tokens[(idx + 1)...end_idx]

      result = +""
      if evaluate_condition(condition, context)
        inner_out, _ = render_block(inner_tokens, 0, context)
        result = inner_out
      end

      [output + result, end_idx + 1]
    end

    # ── Variable resolution ────────────────────────────────────────────────────
    # Resolves "object.attribute.nested" via dot-notation on the Hash context.
    # Returns nil if any step fails — no exceptions raised.
    def resolve(path, context)
      path.strip.split(".").reduce(context) do |obj, key|
        break nil unless obj.is_a?(Hash)
        obj[key] || obj[key.to_sym]
      end
    end

    def render_variable(path, context)
      value = resolve(path, context)
      # HTML-escape all output — prevents XSS in template variables
      CGI.escapeHTML(value.to_s)
    end

    # ── Condition evaluator ────────────────────────────────────────────────────
    # Supports:
    #   truthy variable:    {% if product.in_stock %}
    #   negated variable:   {% if !product.in_stock %}
    #   equality check:     {% if product.status == "active" %}
    #   inequality check:   {% if product.status != "draft" %}
    def evaluate_condition(expr, context)
      expr = expr.strip

      if expr.include?("!=")
        left, right = expr.split("!=", 2).map(&:strip)
        resolve(left, context).to_s != unquote(right)

      elsif expr.include?("==")
        left, right = expr.split("==", 2).map(&:strip)
        resolve(left, context).to_s == unquote(right)

      elsif expr.start_with?("!")
        val = resolve(expr[1..].strip, context)
        !truthy?(val)

      else
        truthy?(resolve(expr, context))
      end
    end

    def truthy?(val)
      return false if val.nil? || val == false || val == "false"
      return false if val.respond_to?(:empty?) && val.empty?
      true
    end

    # Remove surrounding quotes from a literal value in a condition
    def unquote(str)
      str.gsub(/\A['"]|['"]\z/, "")
    end

    # ── Closing tag finder ─────────────────────────────────────────────────────
    # Finds the matching end tag, respecting nesting depth.
    # e.g. for "for"/"endfor", nested {% for %} blocks increment depth.
    def find_closing_tag(tokens, start_idx, open_keyword, close_keyword)
      depth = 1
      idx   = start_idx + 1

      while idx < tokens.size
        token = tokens[idx]

        if token.match?(/\A\{%\s*#{Regexp.escape(open_keyword)}[\s%]/)
          depth += 1
        elsif token.match?(/\A\{%\s*#{Regexp.escape(close_keyword)}\s*%\}\z/)
          depth -= 1
          return idx if depth.zero?
        end

        idx += 1
      end

      # Unclosed tag — treat rest of tokens as body (forgiving parser)
      tokens.size
    end

    # ── Context normalization ──────────────────────────────────────────────────
    # Converts objects to Hash for use inside loops/conditionals.
    def to_context_hash(obj)
      case obj
      when Hash           then deep_stringify(obj)
      when NilClass       then {}
      else
        obj.respond_to?(:to_template_hash) ? obj.to_template_hash : {}
      end
    end

    def deep_stringify(hash)
      return hash unless hash.is_a?(Hash)
      hash.each_with_object({}) do |(k, v), acc|
        acc[k.to_s] = v.is_a?(Hash) ? deep_stringify(v) : v
      end
    end
  end
end
