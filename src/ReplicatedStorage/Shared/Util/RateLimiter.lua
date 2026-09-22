--!strict
-- RateLimiter: token-bucket per key (used to throttle remote spam per player).

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(ratePerSecond: number, burst: number)
	return setmetatable({
		_rate = ratePerSecond,
		_burst = burst or ratePerSecond,
		_buckets = {},
	}, RateLimiter)
end

-- Returns true if the action is allowed for `key`, false if rate-limited.
function RateLimiter:Check(key: any): boolean
	local now = os.clock()
	local b = self._buckets[key]
	if not b then
		b = { tokens = self._burst, last = now }
		self._buckets[key] = b
	end
	local elapsed = now - b.last
	b.last = now
	b.tokens = math.min(self._burst, b.tokens + elapsed * self._rate)
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter:Clear(key: any)
	self._buckets[key] = nil
end

return RateLimiter
