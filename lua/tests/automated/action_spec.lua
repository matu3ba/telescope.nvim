local actions = require('telescope.actions')
local action_set = require('telescope.actions.set')

local transform_mod = require('telescope.actions.mt').transform_mod

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('actions', function()
  it('should allow creating custom actions', function()
    local a = transform_mod {
      x = function() return 5 end,
    }


    eq(5, a.x())
  end)

  it('allows adding actions', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local x_plus_y = a.x + a.y

    eq({"x", "y"}, {x_plus_y()})
  end)

  it('ignores nils from added actions', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
      nil_maker = function() return nil end,
    }

    local x_plus_y = a.x + a.nil_maker + a.y

    eq({"x", "y"}, {x_plus_y()})
  end)

  it('allows overriding an action', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    -- actions.file_goto_selection_edit:replace(...)
    a.x:replace(function() return "foo" end)
    eq("foo", a.x())

    a._clear()
    eq("x", a.x())
  end)

  it('allows overriding an action only in specific cases with if', function()
    local a = transform_mod {
      x = function(e) return e * 10 end,
      y = function() return "y" end,
    }

    -- actions.file_goto_selection_edit:replace(...)
    a.x:replace_if(
      function(e) return e > 0 end,
      function(e) return (e / 10) end
    )
    eq(-100, a.x(-10))
    eq(10, a.x(100))
    eq(1, a.x(10))

    a._clear()
    eq(100, a.x(10))
  end)

  it('allows overriding an action only in specific cases with mod', function()
    local a = transform_mod {
      x = function(e) return e * 10 end,
      y = function() return "y" end,
    }

    -- actions.file_goto_selection_edit:replace(...)
    a.x:replace_map {
      [function(e) return e > 0 end] = function(e) return (e / 10) end,
      [function(e) return e == 0 end] = function(e) return (e + 10) end,
    }

    eq(-100, a.x(-10))
    eq(10, a.x(100))
    eq(1, a.x(10))
    eq(10, a.x(0))

    a._clear()
    eq(100, a.x(10))
  end)

  it('continuous replacement', function()
    local a = transform_mod {
      x = function() return "cleared" end,
      y = function() return "y" end,
    }

    -- Replace original, which becomes new fallback
    a.x:replace(function() return "negative" end)

    -- actions.file_goto_selection_edit:replace(...)
    a.x:replace_map {
      [function(e) return e > 0 end] = function(e) return "positive" end,
      [function(e) return e == 0 end] = function(e) return "zero" end,
    }

    eq("positive", a.x(10))
    eq("zero"    , a.x(0))
    eq("negative", a.x(-10))

    a._clear()
    eq("cleared", a.x(10))
  end)

  it('enhance.pre', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_pre = false

    a.y:enhance {
      pre = function()
        called_pre = true
      end,
    }
    eq("y", a.y())
    eq(true, called_pre)
  end)

  it('enhance.post', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_post = false

    a.y:enhance {
      post = function()
        called_post = true
      end,
    }
    eq("y", a.y())
    eq(true, called_post)
  end)

  it('can call both', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_count = 0
    local count_inc = function()
      called_count = called_count + 1
    end

    a.y:enhance {
      pre = count_inc,
      post = count_inc,
    }

    eq("y", a.y())
    eq(2, called_count)
  end)

  it('can call both even when combined', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_count = 0
    local count_inc = function()
      called_count = called_count + 1
    end

    a.y:enhance {
      pre = count_inc,
      post = count_inc,
    }

    a.x:enhance {
      post = count_inc
    }

    local x_plus_y = a.x + a.y
    x_plus_y()

    eq(3, called_count)
  end)

  it('clears enhance', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_post = false

    a.y:enhance {
      post = function()
        called_post = true
      end,
    }

    a._clear()

    eq("y", a.y())
    eq(false, called_post)
  end)

  it('handles passing arguments', function()
    local a = transform_mod {
      x = function(bufnr) return string.format("bufnr: %s") end,
    }

    a.x:replace(function(bufnr) return string.format("modified: %s", bufnr) end)
    eq("modified: 5", a.x(5))
  end)

  describe('action_set', function()
    it('can replace `action_set.edit`', function()
      action_set.edit:replace(function(_, arg) return "replaced:" .. arg end)
      eq("replaced:edit", actions.goto_file_selection_edit())
      eq("replaced:vnew", actions.goto_file_selection_vsplit())
    end)

    it('handles backwards compat with select and edit files', function()
      -- Reproduce steps:
      --  In config, we have { ["<CR>"] = actions.select, ... }
      --  In caller, we have actions._goto:replace(...)
      --  Person calls `select`, does not see update
      action_set.edit:replace(function(_, arg) return "default_to_edit:" .. arg end)
      eq("default_to_edit:edit", actions.select_default())

      action_set.select:replace(function(_, arg) return "override_with_select:" .. arg end)
      eq("override_with_select:default", actions.select_default())

      -- Sometimes you might want to change the default selection...
      --  but you don't want to prohibit the ability to edit the code...
    end)
  end)
end)
