require("util.range")

describe('Range', function()
  local r1 = Range(5, 10)

  it('determines inclusion', function()
    assert.is_true(r1:inc(5))
    assert.is_true(r1:inc(6))
    assert.is_true(r1:inc(10))

    assert.is_false(r1:inc(11))
    assert.is_false(r1:inc(1))
  end)

  it('determines difference', function()
    assert.is_nil(r1:outside('asd'))

    assert.is_equal(r1:outside(5), 0)
    assert.is_equal(r1:outside(4), -1)
    assert.is_equal(r1:outside(12), 2)

    assert.is_equal(r1:outside(100), 90)
  end)

  describe('translate', function()
    local t1 = Range(10, 15)
    local t2 = Range(0, 5)
    it('works', function()
      assert.same(t1, r1:translate(5))
      assert.same(t2, r1:translate(-5))
    end)

    it('returns a copy', function()
      assert.are_not.equal(r1, r1:translate(0))
    end)
  end)

  describe('translates with limit', function()
    local t1 = Range(20, 25)
    local t2 = Range(0, 5)
    it('works', function()
      assert.same(t1, r1:translate_limit(50, 0, 25))
      assert.same(t2, r1:translate_limit(-50, 0, 25))
    end)

    it('returns a copy', function()
      assert.are_not.equal(r1, r1:translate_limit(0, 0, 25))
    end)
  end)
end)
