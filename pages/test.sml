<documentname>TestDocument</documentname>

<page tier="3"> <!-- This is the root of the page DOM -->
	<frame id="f1" pos="1,1" size="40,10" text="High-resolution page" fcolor="00FF00" textcolor = "FFFF00"/>
	<frame id="f2" pos="1,11" size="40,10" text="With text"/>
	<frame id="f3" pos="50,2" size="40,10" text="With colored text" textcolor = "00FF00" fcolor="FF0000"/>
	<frame id="f4" text="Nesting" pos="10,29" size="60,20" textcolor = "BBBBBB">
		<frame id="f5" pos="-5,2" size="40,10" text="Nested" textcolor="00FF00">
			<frame id="f6" pos="32,5" size="5,5"/>
		</frame>
		
	</frame>
</page>

<!-- If multiple pages exist, the one closest to the current resolution will be used -->
<page tier="2">
	<frame id="f1" pos="1,1" size="30,30" text="Low-resolution page" textcolor="FF0000" fcolor="AAAAAA"/>
</page>