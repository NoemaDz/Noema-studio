from fpdf import FPDF
pdf = FPDF()
pdf.add_page()
pdf.set_font("Arial", size=15)
story = """The Silent Forest
Scene 1:
A dense, misty forest at dawn. The sun rays barely pierce through the thick canopy. A lone wolf stands on a mossy rock, looking into the distance, its silver fur glowing faintly in the morning light. The atmosphere is tense and quiet.

Scene 2:
Suddenly, a flock of crows takes off from the trees, shattering the silence. The wolf turns sharply, baring its teeth. In the shadows of the trees, a pair of glowing red eyes appears. The wolf prepares to pounce."""
pdf.multi_cell(0, 10, txt=story)
pdf.output("story.pdf")
