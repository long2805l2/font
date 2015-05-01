package font;
import Encoding.DefaultEncoding;
// var path = require('./path');
// var sfnt = require('./tables/sfnt');

// A Font represents a loaded OpenType font file.
// It contains a set of glyphs and methods to draw text on a drawing context,
// or to get a path representing the text.
class Font
{
	public var familyName = " ";
	public var styleName = " ";
	public var designer = " ";
	public var designerURL = " ";
	public var manufacturer = " ";
	public var manufacturerURL = " ";
	public var license = " ";
	public var licenseURL = " ";
	public var version = "Version 0.1";
	public var description = " ";
	public var copyright = " ";
	public var trademark = " ";
	public var unitsPerEm = 1000;
	public var supported = true;
	public var glyphs = null;
	public var encoding = null;
	public var tables = null;

	public function new (options)
	{
		if (options.familyName != null)
			this.familyName = options.familyName;
		
		if (options.styleName != null)
			this.styleName = options.styleName;
		
		if (options.designer != null)
			this.designer = options.designer;
		
		if (options.designerURL != null)
			this.designerURL = options.designerURL;
		
		if (options.manufacturer != null)
			this.manufacturer = options.manufacturer;
		
		if (options.manufacturerURL != null)
			this.manufacturerURL = options.manufacturerURL;
		
		if (options.license != null)
			this.license = options.license;
		
		if (options.licenseURL != null)
			this.licenseURL = options.licenseURL;
		
		if (options.version != null)
			this.version = options.version;
		
		if (options.description != null)
			this.description = options.description;
		
		if (options.copyright != null)
			this.copyright = options.copyright;
		
		if (options.trademark != null)
			this.trademark = options.trademark;
		
		if (options.unitsPerEm != null)
			this.unitsPerEm = options.unitsPerEm;
		
		if (options.supported != null)
			this.supported = true;
		
		if (options.glyphs != null)
			this.glyphs = options.glyphs;
		else
			this.glyphs = [];
		
		this.encoding = new DefaultEncoding (this);
		this.tables = new Map<String, Dynamic>;
	}

	// Check if the font has a glyph for the given character.
	public function hasChar (c)
	{
		return this.encoding.charToGlyphIndex(c) !== null;
	};

	// Convert the given character to a single glyph index.
	// Note that this function assumes that there is a one-to-one mapping between
	// the given character and a glyph; for complex scripts this might not be the case.
	public function charToGlyphIndex (s)
	{
		return this.encoding.charToGlyphIndex(s);
	};

	// Convert the given character to a single Glyph object.
	// Note that this function assumes that there is a one-to-one mapping between
	// the given character and a glyph; for complex scripts this might not be the case.
	public function charToGlyph (c)
	{
		var glyphIndex, glyph;
		glyphIndex = this.charToGlyphIndex(c);
		glyph = this.glyphs[glyphIndex];
		if (!glyph)
		{
			glyph = this.glyphs[0]; // .notdef
		}
		return glyph;
	};

	// Convert the given text to a list of Glyph objects.
	// Note that there is no strict one-to-one mapping between characters and
	// glyphs, so the list of returned glyphs can be larger or smaller than the
	// length of the given string.
	public function stringToGlyphs (s)
	{
		var i, c, glyphs;
		glyphs = [];
		for (i = 0; i < s.length; i += 1)
		{
			c = s[i];
			glyphs.push(this.charToGlyph(c));
		}
		return glyphs;
	};

	public function nameToGlyphIndex (name)
	{
		return this.glyphNames.nameToGlyphIndex(name);
	};

	public function nameToGlyph (name)
	{
		var glyphIndex, glyph;
		glyphIndex = this.nametoGlyphIndex(name);
		glyph = this.glyphs[glyphIndex];
		if (!glyph) {
			glyph = this.glyphs[0]; // .notdef
		}
		return glyph;
	};

	public function glyphIndexToName (gid)
	{
		if (!this.glyphNames.glyphIndexToName)
		{
			return "";
		}
		return this.glyphNames.glyphIndexToName(gid);
	};

	// Retrieve the value of the kerning pair between the left glyph (or its index)
	// and the right glyph (or its index). If no kerning pair is found, return 0.
	// The kerning value gets added to the advance width when calculating the spacing
	// between glyphs.
	public function getKerningValue (leftGlyph, rightGlyph)
	{
		leftGlyph = leftGlyph.index || leftGlyph;
		rightGlyph = rightGlyph.index || rightGlyph;
		var gposKerning = this.getGposKerningValue;
		return gposKerning ? gposKerning(leftGlyph, rightGlyph) :
			(this.kerningPairs[leftGlyph + "," + rightGlyph] || 0);
	};

	// Helper function that invokes the given callback for each glyph in the given text.
	// The callback gets `(glyph, x, y, fontSize, options)`.
	public function forEachGlyph (text, x, y, fontSize, options, callback)
	{
		var kerning, fontScale, glyphs, i, glyph, kerningValue;
		if (!this.supported)
		{
			return;
		}
		x = x !== undefined ? x : 0;
		y = y !== undefined ? y : 0;
		fontSize = fontSize !== undefined ? fontSize : 72;
		options = options || {};
		kerning = options.kerning === undefined ? true : options.kerning;
		fontScale = 1 / this.unitsPerEm * fontSize;
		glyphs = this.stringToGlyphs(text);

		for (i = 0; i < glyphs.length; i += 1)
		{
			glyph = glyphs[i];
			callback(glyph, x, y, fontSize, options);

			if (glyph.advanceWidth)
			{
				x += glyph.advanceWidth * fontScale;
			}

			if (kerning && i < glyphs.length - 1)
			{
				kerningValue = this.getKerningValue(glyph, glyphs[i + 1]);
				x += kerningValue * fontScale;
			}
		}
	};

	// Create a Path object that represents the given text.
	//
	// text - The text to create.
	// x - Horizontal position of the beginning of the text. (default: 0)
	// y - Vertical position of the *baseline* of the text. (default: 0)
	// fontSize - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`. (default: 72)
	// Options is an optional object that contains:
	// - kerning - Whether to take kerning information into account. (default: true)
	//
	// Returns a Path object.
	public function getPath (text, x, y, fontSize, options)
	{
		var fullPath = new path.Path();
		this.forEachGlyph(text, x, y, fontSize, options, function (glyph, x, y, fontSize)
		{
			var path = glyph.getPath(x, y, fontSize);
			fullPath.extend(path);
		});
		return fullPath;
	};

	// Draw the text on the given drawing context.
	//
	// ctx - A 2D drawing context, like Canvas.
	// text - The text to create.
	// x - Horizontal position of the beginning of the text. (default: 0)
	// y - Vertical position of the *baseline* of the text. (default: 0)
	// fontSize - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`. (default: 72)
	// Options is an optional object that contains:
	// - kerning - Whether to take kerning information into account. (default: true)
	public function draw (ctx, text, x, y, fontSize, options)
	{
		this.getPath(text, x, y, fontSize, options).draw(ctx);
	};

	// Draw the points of all glyphs in the text.
	// On-curve points will be drawn in blue, off-curve points will be drawn in red.
	//
	// ctx - A 2D drawing context, like Canvas.
	// text - The text to create.
	// x - Horizontal position of the beginning of the text. (default: 0)
	// y - Vertical position of the *baseline* of the text. (default: 0)
	// fontSize - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`. (default: 72)
	// Options is an optional object that contains:
	// - kerning - Whether to take kerning information into account. (default: true)
	public function drawPoints (ctx, text, x, y, fontSize, options)
	{
		this.forEachGlyph(text, x, y, fontSize, options, function (glyph, x, y, fontSize)
		{
			glyph.drawPoints(ctx, x, y, fontSize);
		});
	};

	// Draw lines indicating important font measurements for all glyphs in the text.
	// Black lines indicate the origin of the coordinate system (point 0,0).
	// Blue lines indicate the glyph bounding box.
	// Green line indicates the advance width of the glyph.
	//
	// ctx - A 2D drawing context, like Canvas.
	// text - The text to create.
	// x - Horizontal position of the beginning of the text. (default: 0)
	// y - Vertical position of the *baseline* of the text. (default: 0)
	// fontSize - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`. (default: 72)
	// Options is an optional object that contains:
	// - kerning - Whether to take kerning information into account. (default: true)
	public function drawMetrics (ctx, text, x, y, fontSize, options)
	{
		this.forEachGlyph(text, x, y, fontSize, options, function (glyph, x, y, fontSize)
		{
			glyph.drawMetrics(ctx, x, y, fontSize);
		});
	};

	// Validate
	public function validate ()
	{
		var warnings = [];
		var font = this;

		function assert(predicate, message)
		{
			if (!predicate) {
				warnings.push(message);
			}
		}

		function assertStringAttribute(attrName)
		{
			assert(font[attrName] && font[attrName].trim().length > 0, "No " + attrName + " specified.");
		}

		// Identification information
		assertStringAttribute("familyName");
		assertStringAttribute("weightName");
		assertStringAttribute("manufacturer");
		assertStringAttribute("copyright");
		assertStringAttribute("version");

		// Dimension information
		assert(this.unitsPerEm > 0, "No unitsPerEm specified.");
	};

	// Convert the font object to a SFNT data structure.
	// This structure contains all the necessary tables and metadata to create a binary OTF file.
	public function toTables ()
	{
		return sfnt.fontToTable (this);
	};

	public function toBuffer ()
	{
		var sfntTable = this.toTables();
		var bytes = sfntTable.encode();
		var buffer = new ArrayBuffer(bytes.length);
		var intArray = new Uint8Array(buffer);

		for (var i = 0; i < bytes.length; i++)
		{
			intArray[i] = bytes[i];
		}
		return buffer;
	};

	// Initiate a download of the OpenType font.
	public function download ()
	{
		var fileName = this.familyName.replace(/\s/g, "") + "-" + this.styleName + ".otf";
		var buffer = this.toBuffer();

		window.requestFileSystem = window.requestFileSystem || window.webkitRequestFileSystem;
		window.requestFileSystem(window.TEMPORARY, buffer.byteLength, function (fs)
		{
			fs.root.getFile(fileName, {create: true}, function (fileEntry)
			{
				fileEntry.createWriter(function (writer)
				{
					var dataView = new DataView(buffer);
					var blob = new Blob([dataView], {type: "font/opentype"});
					writer.write(blob);

					writer.addEventListener("writeend", function ()
					{
						// Navigating to the file will download it.
						location.href = fileEntry.toURL();
					}, false);
				});
			});
		},
		function (err)
		{
			throw err;
		});
	};
}