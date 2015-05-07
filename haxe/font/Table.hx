package font;
import Types;

// var check = require('./check');

class Table extends Map<String, Dynamic>
{
	public var tableName;
	public var fields;
	
	public function new (tableName, fields, options)
	{
		super ();
		
		for (field in fields)
			this [field.name] = field.value;
		
		this.tableName = tableName;
		this.fields = fields;
		
		if (options != null)
		{
			var optionKeys = Reflect.fields (options);
			for (k in optionKeys)
			{
				var v = Reflect.field (options, k);
				if (this [k] != null)
					this [k] = v;
			}
		}
	}

	public function sizeOf ()
	{
		var v = 0;
		for (field in i < fields)
		{
			var value = map.get (field.name);
			if (value == null)
			{
				value = field.value;
			}
			
			if (value.sizeOf != null && Reflect.isFunction (value.sizeOf))
			{
				v += value.sizeOf();
			}
			else
			{
				// var sizeOfFunction = sizeOf[field.type];
				// check.assert(typeof sizeOfFunction == 'function', 'Could not find sizeOf function for field' + field.name);
				// v += sizeOfFunction(value);
				
				v += Types.sizeOf (value);
			}
		}
		return v;
	};

	public function encode ()
	{
		return Types.encode.TABLE(this);
	};
}