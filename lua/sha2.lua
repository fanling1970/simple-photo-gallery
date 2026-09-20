local sha2 = {}
local bit = require "bit"
local band, bxor, bor, rshift, lshift = bit.band, bit.bxor, bit.bor, bit.rshift, bit.lshift
local floor = math.floor

local K = {0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
           0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
           0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
           0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
           0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
           0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
           0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
           0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}

local function rotr(x, n) return bor(rshift(x, n), band(lshift(x, 32 - n), 0xffffffff)) end

local function be32(n)
    return string.char(floor(n/0x1000000)%0x100, floor(n/0x10000)%0x100, floor(n/0x100)%0x100, n%0x100)
end

local function digest(msg)
    local len = #msg
    local H = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    local bitlen = len * 8
    local padded = msg .. string.char(0x80)
    while (#padded % 64) ~= 56 do padded = padded .. string.char(0) end
    local hi = floor(bitlen / 0x100000000)
    local lo = bitlen % 0x100000000
    padded = padded .. be32(hi) .. be32(lo)

    for i = 1, #padded, 64 do
        local w = {}
        for j = 1, 16 do
            local s = i + (j - 1) * 4
            w[j] = (string.byte(padded, s) * 0x1000000)
                 + (string.byte(padded, s+1) * 0x10000)
                 + (string.byte(padded, s+2) * 0x100)
                 + string.byte(padded, s+3)
        end
        for j = 17, 64 do
            local x = w[j-15]
            local s0 = bxor(rotr(x,7), rotr(x,18), rshift(x,3))
            local y = w[j-2]
            local s1 = bxor(rotr(y,17), rotr(y,19), rshift(y,10))
            w[j] = band(w[j-16] + s0 + w[j-7] + s1, 0xffffffff)
        end
        local a,b,c,d,e,f,g,h = H[1],H[2],H[3],H[4],H[5],H[6],H[7],H[8]
        for j = 1, 64 do
            local S1 = bxor(rotr(e,6), rotr(e,11), rotr(e,25))
            local ch = bxor(band(e,f), band(bxor(e,0xffffffff),g))
            local t1 = band(h + S1 + ch + K[j] + w[j], 0xffffffff)
            local S0 = bxor(rotr(a,2), rotr(a,13), rotr(a,22))
            local maj = bxor(band(a,b), band(a,c), band(b,c))
            local t2 = band(S0 + maj, 0xffffffff)
            h,g,f,e,d,c,b,a = g,f,e,band(d+t1,0xffffffff),c,b,a,band(t1+t2,0xffffffff)
        end
        H[1]=band(H[1]+a,0xffffffff); H[2]=band(H[2]+b,0xffffffff)
        H[3]=band(H[3]+c,0xffffffff); H[4]=band(H[4]+d,0xffffffff)
        H[5]=band(H[5]+e,0xffffffff); H[6]=band(H[6]+f,0xffffffff)
        H[7]=band(H[7]+g,0xffffffff); H[8]=band(H[8]+h,0xffffffff)
    end
    return be32(H[1])..be32(H[2])..be32(H[3])..be32(H[4])
         ..be32(H[5])..be32(H[6])..be32(H[7])..be32(H[8])
end

function sha2.hex(msg)
    return (digest(msg):gsub('.', function(c) return string.format('%02x', string.byte(c)) end))
end

return sha2
