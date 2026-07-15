LVector = {}
LVector.__index = LVector

function LVector.newVector( x, y )
    return setmetatable( { x = x or 0, y = y or 0 }, LVector )
end

function isvector( vTbl )
    return getmetatable( vTbl ) == LVector
end

function LVector.__unm( vTbl )
    return LVector.newVector( -vTbl.x, -vTbl.y )
end

function LVector.__add( a, b )
    return LVector.newVector( a.x + b.x, a.y + b.y )
end

function LVector.__sub( a, b )
    return LVector.newVector( a.x - b.x, a.y - b.y )
end

function LVector.__mul( a, b )
    if type( a ) == "number" then
        return LVector.newVector( a * b.x, a * b.y )
    elseif type( b ) == "number" then
        return LVector.newVector( a.x * b, a.y * b )
    else
        return LVector.newVector( a.x * b.x, a.y * b.y )
    end
end

function LVector.__div( a, b )
    return LVector.newVector( a.x / b, a.y / b )
end

function LVector.__eq( a, b )
    return a.x == b.x and a.y == b.y
end

function LVector:__tostring()
    return "(" .. self.x .. ", " .. self.y .. ")"
end

function LVector:ID()
    if self._ID == nil then
        local x, y = self.x, self.y
        self._ID = 0.5 * ( ( x + y ) * ( x + y + 1 ) + y )
    end

    return self._ID
end

return setmetatable( LVector, { __call = function( _, ... ) return LVector.newVector( ... ) end } )