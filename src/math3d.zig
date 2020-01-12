const std = @import("std");

comptime {
    @import("std").meta.refAllDecls(@This());
}

fn SwizzleTypeByElements(comptime i: usize) type {
    return switch (i) {
        1 => f32,
        2 => Vec2,
        3 => Vec3,
        4 => Vec4,
        else => @compileError("Swizzle can take up to 4 elements!"),
    };
}

fn VectorMixin(comptime Self: type) type {
    return struct {
        /// adds all components from `a` with the components of `b`.
        pub fn add(a: Self, b: Self) Self {
            var result: Self = undefined;
            inline for (@typeInfo(Self).Struct.fields) |fld| {
                @field(result, fld.name) = @field(a, fld.name) + @field(b, fld.name);
            }
            return result;
        }

        /// subtracts all components from `a` with the components of `b`.
        pub fn sub(a: Self, b: Self) Self {
            var result: Self = undefined;
            inline for (@typeInfo(Self).Struct.fields) |fld| {
                @field(result, fld.name) = @field(a, fld.name) - @field(b, fld.name);
            }
            return result;
        }

        /// multiplies all components from `a` with the components of `b`.
        pub fn mul(a: Self, b: Self) Self {
            var result: Self = undefined;
            inline for (@typeInfo(Self).Struct.fields) |fld| {
                @field(result, fld.name) = @field(a, fld.name) * @field(b, fld.name);
            }
            return result;
        }

        /// divides all components from `a` by the components of `b`.
        pub fn div(a: Self, b: Self) Self {
            var result: Self = undefined;
            inline for (@typeInfo(Self).Struct.fields) |fld| {
                @field(result, fld.name) = @field(a, fld.name) / @field(b, fld.name);
            }
            return result;
        }

        /// multiplies all components by a scalar value.
        pub fn scale(a: Self, b: f32) Self {
            var result: Self = undefined;
            inline for (@typeInfo(Self).Struct.fields) |fld| {
                @field(result, fld.name) = @field(a, fld.name) * b;
            }
            return result;
        }

        /// returns the dot product of two vectors.
        /// This is the sum of products of all components.
        pub fn dot(a: Self, b: Self) f32 {
            var result: f32 = 0;
            inline for (@typeInfo(Self).Struct.fields) |fld| {
                result += @field(a, fld.name) * @field(b, fld.name);
            }
            return result;
        }

        /// returns the magnitude of the vector.
        pub fn length(a: Self) f32 {
            return std.math.sqrt(a.length2());
        }

        /// returns the squared magnitude of the vector.
        pub fn length2(a: Self) f32 {
            return Self.dot(a, a);
        }

        /// returns either a normalized vector (`length() = 1`) or `zero` if the vector
        /// has length 0.
        pub fn normalize(vec: Self) Self {
            var len = vec.length();
            return if (len != 0.0)
                vec.scale(1.0 / vec.length())
            else
                Self.zero;
        }

        /// swizzle vector fields into a new vector type.
        /// swizzle("xxx") will return a Vec3 with three times the x component.
        /// swizzle will return a vector or scalar type with the same number of components as the
        /// `components` string.
        /// `components` may be any sequence of `x`, `y`, `z`, `w`, `0` and `1`.
        /// The letters will be replaced by the corresponding component, the digits will be replaced
        /// by the corresponding literal value.
        ///
        /// Examples:
        /// - `vec4(1,2,3,4).swizzle("wzyx") == vec4(4, 3, 2, 1)`
        /// - `vec4(1,2,3,4).swizzle("xyx") == vec3(1,2,1)`
        /// - `vec2(1,2).swizzle("xyxy") == vec4(1,2,1,2)`
        /// - `vec2(3,4).swizzle("xy01") == vec4(3, 4, 0, 1)`
        ///
        pub fn swizzle(self: Self, comptime components: []const u8) SwizzleTypeByElements(components.len) {
            const T = SwizzleTypeByElements(components.len);
            var result: T = undefined;

            if (components.len > 1) {
                const fieldorder = "xyzw";
                inline for (components) |c, i| {
                    const slice = components[i .. i + 1];
                    const temp = if (std.mem.eql(u8, slice, "0")) @as(f32, 0) else comptime if (std.mem.eql(u8, slice, "1")) @as(f32, 1) else @field(self, slice);
                    @field(result, switch (i) {
                        0 => "x",
                        1 => "y",
                        2 => "z",
                        3 => "w",
                        else => @compileError("this should not happen"),
                    }) = temp;
                }
            } else if (components.len == 1) {
                result = @field(self, components);
            } else {
                @compileError("components must at least contain a single field!");
            }

            return result;
        }

        /// returns a new vector where each component is the minimum of the components of the input vectors.
        pub fn componentMin(a: Self, b: Self) Self {
            var result: Self = undefined;
            inline for (@typeInfo(Self).Struct.fields) |fld| {
                @field(result, fld.name) = std.math.min(@field(a, fld.name), @field(b, fld.name));
            }
            return result;
        }

        /// returns a new vector where each component is the maximum of the components of the input vectors.
        pub fn componentMax(a: Self, b: Self) Self {
            var result: Self = undefined;
            inline for (@typeInfo(Self).Struct.fields) |fld| {
                @field(result, fld.name) = std.math.max(@field(a, fld.name), @field(b, fld.name));
            }
            return result;
        }
    };
}

/// 2-dimensional vector type.
pub const Vec2 = extern struct {
    const Self = @This();

    x: f32,
    y: f32,

    pub const zero = Self.new(0, 0);
    pub const unitX = Self.new(1, 0);
    pub const unitY = Self.new(0, 1);

    usingnamespace VectorMixin(Self);

    pub fn new(x: f32, y: f32) Self {
        return Self{
            .x = x,
            .y = y,
        };
    }

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try std.fmt.format(context, Errors, output, "vec2({d:.2}, {d:.2})", value.x, value.y);
    }

    fn getField(vec: Self, comptime index: comptime_int) f32 {
        switch (index) {
            0 => return vec.x,
            1 => return vec.y,
            else => @compileError("index out of bounds!"),
        }
    }

    /// multiplies the vector with a matrix.
    pub fn transform(vec: Self, mat: Mat2) Self {
        var result = zero;
        inline for ([_]comptime_int{ 0, 1 }) |i| {
            result.x += vec.getField(i) * mat.fields[0][i];
            result.y += vec.getField(i) * mat.fields[1][i];
        }
        return result;
    }
};

/// 3-dimensional vector type.
pub const Vec3 = extern struct {
    const Self = @This();

    x: f32,
    y: f32,
    z: f32,

    pub const zero = Self.new(0, 0, 0);
    pub const unitX = Self.new(1, 0, 0);
    pub const unitY = Self.new(0, 1, 0);
    pub const unitZ = Self.new(0, 0, 1);

    usingnamespace VectorMixin(Self);

    pub fn new(x: f32, y: f32, z: f32) Self {
        return Self{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try std.fmt.format(context, Errors, output, "vec3({d:.2}, {d:.2}, {d:.2})", value.x, value.y, value.z);
    }

    /// calculates the cross product. result will be perpendicular to a and b.
    pub fn cross(a: Self, b: Self) Self {
        return Self{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    /// converts the vector from an homogeneous position (w=1).
    pub fn toAffinePosition(a: Self) Vec4 {
        return Vec4{
            .x = a.x,
            .y = a.y,
            .z = a.z,
            .w = 1.0,
        };
    }

    /// converts the vector from an homogeneous direction (w=0).
    pub fn toAffineDirection(a: Self) Vec4 {
        return Vec4{
            .x = a.x,
            .y = a.y,
            .z = a.z,
            .w = 0.0,
        };
    }

    pub fn fromAffinePosition(a: Vec4) Self {
        return Vec3{
            .x = a.x / a.w,
            .y = a.y / a.w,
            .z = a.z / a.w,
        };
    }

    pub fn fromAffineDirection(a: Vec4) Self {
        return Vec3{
            .x = a.x,
            .y = a.y,
            .z = a.z,
        };
    }

    /// multiplies the vector with a matrix.
    pub fn transform(vec: Self, mat: Mat3) Self {
        var result = zero;
        inline for ([_]comptime_int{ 0, 1, 2 }) |i| {
            result.x += vec.getField(i) * mat.fields[0][i];
            result.y += vec.getField(i) * mat.fields[1][i];
            result.z += vec.getField(i) * mat.fields[2][i];
        }
        return result;
    }

    /// transforms a homogeneous position.
    pub fn transformPosition(vec: Self, mat: Mat4) Self {
        return fromAffinePosition(vec.toAffinePosition().transform(mat));
    }

    /// transforms a homogeneous direction.
    pub fn transformDirection(vec: Self, mat: Mat4) Self {
        return fromAffineDirection(vec.toAffineDirection().transform(mat));
    }

    fn getField(vec: Self, comptime index: comptime_int) f32 {
        switch (index) {
            0 => return vec.x,
            1 => return vec.y,
            2 => return vec.z,
            else => @compileError("index out of bounds!"),
        }
    }
};

/// 4-dimensional vector type.
pub const Vec4 = extern struct {
    const Self = @This();

    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const zero = Self.new(0, 0, 0, 0);
    pub const unitX = Self.new(1, 0, 0, 0);
    pub const unitY = Self.new(0, 1, 0, 0);
    pub const unitZ = Self.new(0, 0, 1, 0);
    pub const unitW = Self.new(0, 0, 1, 0);

    usingnamespace VectorMixin(Self);

    pub fn new(x: f32, y: f32, z: f32, w: f32) Self {
        return Self{
            .x = x,
            .y = y,
            .z = z,
            .w = w,
        };
    }

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try std.fmt.format(context, Errors, output, "vec4({d:.2}, {d:.2}, {d:.2}, {d:.2})", value.x, value.y, value.z, value.w);
    }

    /// multiplies the vector with a matrix.
    pub fn transform(vec: Self, mat: Mat4) Self {
        var result = zero;
        inline for ([_]comptime_int{ 0, 1, 2, 3 }) |i| {
            result.x += vec.getField(i) * mat.fields[i][0];
            result.y += vec.getField(i) * mat.fields[i][1];
            result.z += vec.getField(i) * mat.fields[i][2];
            result.w += vec.getField(i) * mat.fields[i][3];
        }
        return result;
    }

    fn getField(vec: Self, comptime index: comptime_int) f32 {
        switch (index) {
            0 => return vec.x,
            1 => return vec.y,
            2 => return vec.z,
            3 => return vec.w,
            else => @compileError("index out of bounds!"),
        }
    }
};

/// 2 by 2 matrix type.
pub const Mat2 = extern struct {
    fields: [2][2]f32, // [row][col]

    /// identitiy matrix
    pub const identity = Self{
        .fields = [2]f32{
            [2]f32{ 1, 0 },
            [2]f32{ 0, 1 },
        },
    };
};

/// 3 by 3 matrix type.
pub const Mat3 = extern struct {
    fields: [3][3]f32, // [row][col]

    /// identitiy matrix
    pub const identity = Self{
        .fields = [3]f32{
            [3]f32{ 1, 0, 0 },
            [3]f32{ 0, 1, 0 },
            [3]f32{ 0, 0, 1 },
        },
    };
};

/// 4 by 4 matrix type.
pub const Mat4 = extern struct {
    pub const Self = @This();
    fields: [4][4]f32, // [row][col]

    /// zero matrix.
    pub const zero = Self{
        .fields = [4][4]f32{
            [4]f32{ 0, 0, 0, 0 },
            [4]f32{ 0, 0, 0, 0 },
            [4]f32{ 0, 0, 0, 0 },
            [4]f32{ 0, 0, 0, 0 },
        },
    };

    /// identitiy matrix
    pub const identity = Self{
        .fields = [4][4]f32{
            [4]f32{ 1, 0, 0, 0 },
            [4]f32{ 0, 1, 0, 0 },
            [4]f32{ 0, 0, 1, 0 },
            [4]f32{ 0, 0, 0, 1 },
        },
    };

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "mat4{");

        inline for ([_]comptime_int{ 0, 1, 2, 3 }) |i| {
            const row = value.fields[i];
            try std.fmt.format(context, Errors, output, " ({d:.2} {d:.2} {d:.2} {d:.2})", row[0], row[1], row[2], row[3]);
        }

        try output(context, " }");
    }

    /// performs matrix multiplication of a*b
    pub fn mul(a: Self, b: Self) Self {
        var result: Self = undefined;
        inline for ([_]comptime_int{ 0, 1, 2, 3 }) |row| {
            inline for ([_]comptime_int{ 0, 1, 2, 3 }) |col| {
                var sum: f32 = 0.0;
                inline for ([_]comptime_int{ 0, 1, 2, 3 }) |i| {
                    sum += a.fields[row][i] * b.fields[i][col];
                }
                result.fields[row][col] = sum;
            }
        }
        return result;
    }

    /// transposes the matrix.
    /// this will swap columns with rows.
    pub fn transpose(a: Self) Self {
        var result: Self = undefined;
        inline for ([_]comptime_int{ 0, 1, 2, 3 }) |row| {
            inline for ([_]comptime_int{ 0, 1, 2, 3 }) |col| {
                result.fields[row][col] = a.fields[col][row];
            }
        }
        return result;
    }

    // taken from GLM implementation

    /// Creates a look-at matrix.
    /// The matrix will create a transformation that can be used
    /// as a camera transform.
    /// the camera is located at `eye` and will look into `direction`.
    /// `up` is the direction from the screen center to the upper screen border.
    pub fn createLook(eye: Vec3, direction: Vec3, up: Vec3) Self {
        const f = direction.normalize();
        const s = Vec3.cross(up, f).normalize();
        const u = Vec3.cross(f, s);

        var result = Self.identity;
        result.fields[0][0] = s.x;
        result.fields[1][0] = s.y;
        result.fields[2][0] = s.z;
        result.fields[0][1] = u.x;
        result.fields[1][1] = u.y;
        result.fields[2][1] = u.z;
        result.fields[0][2] = f.x;
        result.fields[1][2] = f.y;
        result.fields[2][2] = f.z;
        result.fields[3][0] = -Vec3.dot(s, eye);
        result.fields[3][1] = -Vec3.dot(u, eye);
        result.fields[3][2] = -Vec3.dot(f, eye);
        return result;
    }

    /// Creates a look-at matrix.
    /// The matrix will create a transformation that can be used
    /// as a camera transform.
    /// the camera is located at `eye` and will look at `center`.
    /// `up` is the direction from the screen center to the upper screen border.
    pub fn createLookAt(eye: Vec3, center: Vec3, up: Vec3) Self {
        return createLook(eye, Vec3.sub(center, eye), up);
    }

    // taken from GLM implementation

    /// creates a perspective transformation matrix.
    /// `fov` is the field of view in radians,
    /// `aspect` is the screen aspect ratio (width / height)
    /// `near` is the distance of the near clip plane, whereas `far` is the distance to the far clip plane.
    pub fn createPerspective(fov: f32, aspect: f32, near: f32, far: f32) Self {
        std.debug.assert(std.math.fabs(aspect - 0.001) > 0);

        const tanHalfFovy = std.math.tan(fov / 2);

        var result = Self.zero;
        result.fields[0][0] = 1.0 / (aspect * tanHalfFovy);
        result.fields[1][1] = 1.0 / (tanHalfFovy);
        result.fields[2][2] = far / (far - near);
        result.fields[2][3] = 1;
        result.fields[3][2] = -(far * near) / (far - near);
        return result;
    }

    /// creates a rotation matrix around a certain axis.
    pub fn createAngleAxis(axis: Vec3, angle: f32) Self {
        var cos = std.math.cos(angle);
        var sin = std.math.sin(angle);
        var x = axis.x;
        var y = axis.y;
        var z = axis.z;

        return Self{
            .fields = [4][4]f32{
                [4]f32{ cos + x * x * (1 - cos), x * y * (1 - cos) - z * sin, x * z * (1 - cos) + y * sin, 0 },
                [4]f32{ y * x * (1 - cos) + z * sin, cos + y * y * (1 - cos), y * z * (1 - cos) - x * sin, 0 },
                [4]f32{ z * x * (1 * cos) - y * sin, z * y * (1 - cos) + x * sin, cos + z * z * (1 - cos), 0 },
                [4]f32{ 0, 0, 0, 1 },
            },
        };
    }

    /// creates matrix that will scale a homogeneous matrix.
    pub fn createScale(scale: f32) Self {
        return Self{
            .fields = [4][4]f32{
                [4]f32{ scale, 0, 0, 0 },
                [4]f32{ 0, scale, 0, 0 },
                [4]f32{ 0, 0, scale, 0 },
                [4]f32{ 0, 0, 0, 1 },
            },
        };
    }

    /// creates matrix that will translate a homogeneous matrix.
    pub fn createTranslationXYZ(x: f32, y: f32, z: f32) Self {
        return Self{
            .fields = [4][4]f32{
                [4]f32{ 1, 0, 0, 0 },
                [4]f32{ 0, 1, 0, 0 },
                [4]f32{ 0, 0, 1, 0 },
                [4]f32{ x, y, z, 1 },
            },
        };
    }

    /// creates matrix that will scale a homogeneous matrix.
    pub fn createTranslation(v: Vec3) Self {
        return Self{
            .fields = [4][4]f32{
                [4]f32{ 1, 0, 0, 0 },
                [4]f32{ 0, 1, 0, 0 },
                [4]f32{ 0, 0, 1, 0 },
                [4]f32{ v.x, v.y, v.z, 1 },
            },
        };
    }

    /// creates an orthogonal projection matrix.
    /// `left`, `right`, `bottom` and `top` are the borders of the screen whereas `near` and `far` define the
    /// distance of the near and far clipping planes.
    pub fn createOrthogonal(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Self {
        var result = Self.identity;
        result.fields[0][0] = 2 / (right - left);
        result.fields[1][1] = 2 / (top - bottom);
        result.fields[2][2] = 1 / (far - near);
        result.fields[3][0] = -(right + left) / (right - left);
        result.fields[3][1] = -(top + bottom) / (top - bottom);
        result.fields[3][2] = -near / (far - near);
        return result;
    }
};

/// constructs a new Vec2.
pub fn vec2(x: f32, y: f32) Vec2 {
    return Vec2.new(x, y);
}

/// constructs a new Vec3.
pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3.new(x, y, z);
}

/// constructs a new Vec4.
pub fn vec4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return Vec4.new(x, y, z, w);
}

const assert = @import("std").debug.assert;

test "constructors" {
    const v2 = vec2(1, 2);
    assert(v2.x == 1);
    assert(v2.y == 2);

    const v3 = vec3(1, 2, 3);
    assert(v3.x == 1);
    assert(v3.y == 2);
    assert(v3.z == 3);

    const v4 = vec4(1, 2, 3, 4);
    assert(v4.x == 1);
    assert(v4.y == 2);
    assert(v4.z == 3);
    assert(v4.w == 4);
}

test "vec2 arithmetics" {
    const a = vec2(2, 1);
    const b = vec2(1, 2);

    assert(std.meta.eql(Vec2.add(a, b), vec2(3, 3)));
    assert(std.meta.eql(Vec2.sub(a, b), vec2(1, -1)));
    assert(std.meta.eql(Vec2.mul(a, b), vec2(2, 2)));
    assert(std.meta.eql(Vec2.div(a, b), vec2(2, 0.5)));
    assert(std.meta.eql(Vec2.scale(a, 2.0), vec2(4, 2)));

    assert(Vec2.dot(a, b) == 4.0);

    assert(Vec2.length2(a) == 5.0);
    assert(Vec2.length(a) == std.math.sqrt(5.0));
    assert(Vec2.length(b) == std.math.sqrt(5.0));
}

test "vec3 arithmetics" {
    const a = vec3(2, 1, 3);
    const b = vec3(1, 2, 3);

    assert(std.meta.eql(Vec3.add(a, b), vec3(3, 3, 6)));
    assert(std.meta.eql(Vec3.sub(a, b), vec3(1, -1, 0)));
    assert(std.meta.eql(Vec3.mul(a, b), vec3(2, 2, 9)));
    assert(std.meta.eql(Vec3.div(a, b), vec3(2, 0.5, 1)));
    assert(std.meta.eql(Vec3.scale(a, 2.0), vec3(4, 2, 6)));

    assert(Vec3.dot(a, b) == 13.0);

    assert(Vec3.length2(a) == 14.0);
    assert(Vec3.length(a) == std.math.sqrt(14.0));
    assert(Vec3.length(b) == std.math.sqrt(14.0));

    assert(std.meta.eql(Vec3.cross(vec3(1, 2, 3), vec3(-7, 8, 9)), vec3(-6, -30, 22)));
}

test "vec4 arithmetics" {
    const a = vec4(2, 1, 4, 3);
    const b = vec4(1, 2, 3, 4);

    assert(std.meta.eql(Vec4.add(a, b), vec4(3, 3, 7, 7)));
    assert(std.meta.eql(Vec4.sub(a, b), vec4(1, -1, 1, -1)));
    assert(std.meta.eql(Vec4.mul(a, b), vec4(2, 2, 12, 12)));
    assert(std.meta.eql(Vec4.div(a, b), vec4(2, 0.5, 4.0 / 3.0, 3.0 / 4.0)));
    assert(std.meta.eql(Vec4.scale(a, 2.0), vec4(4, 2, 8, 6)));

    assert(Vec4.dot(a, b) == 28.0);

    assert(Vec4.length2(a) == 30.0);
    assert(Vec4.length(a) == std.math.sqrt(30.0));
    assert(Vec4.length(b) == std.math.sqrt(30.0));
}

test "vec3 <-> vec4 interop" {
    const v = vec3(1, 2, 3);
    const pos = vec4(1, 2, 3, 1);
    const dir = vec4(1, 2, 3, 0);

    assert(std.meta.eql(Vec3.toAffinePosition(v), pos));
    assert(std.meta.eql(Vec3.toAffineDirection(v), dir));

    assert(std.meta.eql(Vec3.fromAffinePosition(pos), v));
    assert(std.meta.eql(Vec3.fromAffineDirection(dir), v));
}

// TODO: write tests for mat2, mat3

test "mat4 arithmetics" {
    const id = Mat4.identity;

    const mat = Mat4{
        .fields = [4][4]f32{
            // zig fmt: off
            [4]f32{ 1, 2, 3, 4 },
            [4]f32{ 5, 6, 7, 8 },
            [4]f32{ 9, 10, 11, 12 },
            [4]f32{ 13, 14, 15, 16 },
            // zig-fmt: on
        },
    };

    const mat_mult_by_mat_by_hand = Mat4{
        .fields = [4][4]f32{
            // zig fmt: off
            [4]f32{ 90, 100, 110, 120 },
            [4]f32{ 202, 228, 254, 280 },
            [4]f32{ 314, 356, 398, 440 },
            [4]f32{ 426, 484, 542, 600 },
            // zig-fmt: on
        },
    };

    const mat_transposed = Mat4{
        .fields = [4][4]f32{
            [4]f32{ 1, 5, 9, 13 },
            [4]f32{ 2, 6, 10, 14 },
            [4]f32{ 3, 7, 11, 15 },
            [4]f32{ 4, 8, 12, 16 },
        },
    };

    const mat_a = Mat4{
        .fields = [4][4]f32{
            [4]f32{ 1, 2, 3, 1 },
            [4]f32{ 2, 3, 1, 2 },
            [4]f32{ 3, 1, 2, 3 },
            [4]f32{ 1, 2, 3, 1 },
        },
    };

    const mat_b = Mat4{
        .fields = [4][4]f32{
            [4]f32{ 3, 2, 1, 3 },
            [4]f32{ 2, 1, 3, 2 },
            [4]f32{ 1, 3, 2, 1 },
            [4]f32{ 3, 2, 1, 3 },
        },
    };

    const mat_a_times_b = Mat4{
        .fields = [4][4]f32{
            [4]f32{ 13, 15, 14, 13 },
            [4]f32{ 19, 14, 15, 19 },
            [4]f32{ 22, 19, 13, 22 },
            [4]f32{ 13, 15, 14, 13 },
        },
    };

    const mat_b_times_a = Mat4{
        .fields = [4][4]f32{
            [4]f32{ 13, 19, 22, 13 },
            [4]f32{ 15, 14, 19, 15 },
            [4]f32{ 14, 15, 13, 14 },
            [4]f32{ 13, 19, 22, 13 },
        },
    };

    // make sure basic properties are not messed up
    assert(std.meta.eql(Mat4.mul(id, id), id));
    assert(std.meta.eql(Mat4.mul(mat, id), mat));
    assert(std.meta.eql(Mat4.mul(id, mat), mat));

    assert(std.meta.eql(Mat4.mul(mat, mat), mat_mult_by_mat_by_hand));
    assert(std.meta.eql(Mat4.mul(mat_a, mat_b), mat_a_times_b));
    assert(std.meta.eql(Mat4.mul(mat_b, mat_a), mat_b_times_a));

    assert(std.meta.eql(Mat4.transpose(mat), mat_transposed));
}

test "vec4 transform" {
    const id = Mat4.identity;

    const mat = Mat4{
        .fields = [4][4]f32{
            // zig fmt: off
            [4]f32{ 1, 2, 3, 4 },
            [4]f32{ 5, 6, 7, 8 },
            [4]f32{ 9, 10, 11, 12 },
            [4]f32{ 13, 14, 15, 16 },
            // zig-fmt: on
        },
    };

    const transform = Mat4{
        .fields = [4][4]f32{
            // zig fmt: off
            [4]f32{ 2, 0, 0, 0 },
            [4]f32{ 0, 2, 0, 0 },
            [4]f32{ 0, 0, 2, 0 },
            [4]f32{ 10, 20, 30, 1 },
            // zig-fmt: on
        },
    };

    const vec = vec4(1, 2, 3, 4);

    assert(std.meta.eql(Vec4.transform(vec, mat), vec4(90, 100, 110, 120)));
    assert(std.meta.eql(Vec4.transform(vec4(1, 2, 3, 1), transform), vec4(12, 24, 36, 1)));
    assert(std.meta.eql(Vec4.transform(vec4(1, 2, 3, 0), transform), vec4(2, 4, 6, 0)));
}
