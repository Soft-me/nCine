#include "TextNode.h"
#include "FontGlyph.h"
#include "Texture.h"
#include "RenderCommand.h"
#include "GLDebug.h"
#include "tracy.h"

namespace ncine {

///////////////////////////////////////////////////////////
// CONSTRUCTORS and DESTRUCTOR
///////////////////////////////////////////////////////////

TextNode::TextNode(SceneNode *parent, Font *font)
    : TextNode(parent, font, DefaultStringLength)
{
}

TextNode::TextNode(SceneNode *parent, Font *font, unsigned int maxStringLength)
    : DrawableNode(parent, 0.0f, 0.0f), string_(maxStringLength), dirtyDraw_(true),
      dirtyBoundaries_(true), withKerning_(true), font_(font),
      interleavedVertices_(maxStringLength * 4 + (maxStringLength - 1) * 2),
      xAdvance_(0.0f), xAdvanceSum_(0.0f), yAdvance_(0.0f), yAdvanceSum_(0.0f),
      lineLengths_(4), alignment_(Alignment::LEFT), textnodeBlock_(nullptr)
{
	ASSERT(font);
	ASSERT(maxStringLength > 0);

	type_ = ObjectType::TEXTNODE;
	setLayer(DrawableNode::LayerBase::HUD);
	renderCommand_->setType(RenderCommand::CommandTypes::TEXT);
	renderCommand_->material().setTransparent(true);
	const Material::ShaderProgramType shaderProgramType = font_->renderMode() == Font::RenderMode::GLYPH_IN_RED
	                                                          ? Material::ShaderProgramType::TEXTNODE_RED
	                                                          : Material::ShaderProgramType::TEXTNODE_ALPHA;
	renderCommand_->material().setShaderProgramType(shaderProgramType);
	textnodeBlock_ = renderCommand_->material().uniformBlock("TextnodeBlock");
	renderCommand_->material().setTexture(*font_->texture());
	renderCommand_->geometry().setPrimitiveType(GL_TRIANGLE_STRIP);
	renderCommand_->geometry().setNumElementsPerVertex(sizeof(Vertex) / sizeof(float));
}

///////////////////////////////////////////////////////////
// PUBLIC FUNCTIONS
///////////////////////////////////////////////////////////

float TextNode::width() const
{
	calculateBoundaries();
	return xAdvanceSum_ * scaleFactor_;
}

float TextNode::height() const
{
	calculateBoundaries();
	return yAdvanceSum_ * scaleFactor_;
}

float TextNode::absWidth() const
{
	calculateBoundaries();
	return xAdvanceSum_ * absScaleFactor_;
}

float TextNode::absHeight() const
{
	calculateBoundaries();
	return yAdvanceSum_ * absScaleFactor_;
}

void TextNode::enableKerning(bool withKerning)
{
	if (withKerning != withKerning_)
	{
		withKerning_ = withKerning;
		dirtyDraw_ = true;
		dirtyBoundaries_ = true;
	}
}

void TextNode::setAlignment(Alignment alignment)
{
	if (alignment != alignment_)
	{
		alignment_ = alignment;
		dirtyDraw_ = true;
		dirtyBoundaries_ = true;
	}
}

void TextNode::setString(const nctl::String &string)
{
	if (string_ != string)
	{
		string_ = string;
		dirtyDraw_ = true;
		dirtyBoundaries_ = true;
	}
}

void TextNode::draw(RenderQueue &renderQueue)
{
	// Early-out if the string is empty
	if (string_.isEmpty())
		return;

	// Precalculate boundaries for horizontal alignment
	calculateBoundaries();

	if (dirtyDraw_)
	{
		GLDebug::ScopedGroup scoped("Processing TextNode glyphs");

		// Clear every previous quad before drawing again
		interleavedVertices_.clear();

		unsigned int currentLine = 0;
		xAdvance_ = calculateAlignment(currentLine) - xAdvanceSum_ * 0.5f;
		yAdvance_ = 0.0f - yAdvanceSum_ * 0.5f;
		const unsigned int length = string_.length();
		for (unsigned int i = 0; i < length; i++)
		{
			if (string_[i] == '\n')
			{
				currentLine++;
				xAdvance_ = calculateAlignment(currentLine) - xAdvanceSum_ * 0.5f;
				yAdvance_ += font_->base();
			}
			else
			{
				const FontGlyph *glyph = font_->glyph(static_cast<unsigned int>(string_[i]));
				if (glyph)
				{
					Degenerate degen = Degenerate::NONE;
					if (length > 1)
					{
						if (i == 0)
							degen = Degenerate::END;
						else if (i == length - 1)
							degen = Degenerate::START;
						else
							degen = Degenerate::START_END;
					}
					processGlyph(glyph, degen);

					if (withKerning_)
					{
						// font kerning
						if (i < length - 1)
							xAdvance_ += glyph->kerning(int(string_[i + 1]));
					}
				}
			}
		}

		// Vertices are updated only if the string changes
		renderCommand_->geometry().setNumVertices(interleavedVertices_.size());
		renderCommand_->geometry().setHostVertexPointer(reinterpret_cast<const float *>(interleavedVertices_.data()));
	}

	DrawableNode::draw(renderQueue);
	dirtyDraw_ = false;
}

///////////////////////////////////////////////////////////
// PRIVATE FUNCTIONS
///////////////////////////////////////////////////////////

void TextNode::calculateBoundaries() const
{
	if (dirtyBoundaries_)
	{
		ZoneScoped;
		lineLengths_.clear();
		float xAdvanceMax = 0.0f; // longest line
		xAdvance_ = 0.0f;
		yAdvance_ = 0.0f;
		for (unsigned int i = 0; i < string_.length(); i++)
		{
			if (string_[i] == '\n')
			{
				lineLengths_.pushBack(xAdvance_);
				if (xAdvance_ > xAdvanceMax)
					xAdvanceMax = xAdvance_;
				xAdvance_ = 0.0f;
				yAdvance_ += font_->base();
			}
			else
			{
				const FontGlyph *glyph = font_->glyph(static_cast<unsigned int>(string_[i]));
				if (glyph)
				{
					xAdvance_ += glyph->xAdvance();
					if (withKerning_)
					{
						// font kerning
						if (i < string_.length() - 1)
							xAdvance_ += glyph->kerning(int(string_[i + 1]));
					}
				}
			}
		}

		// If the string does not end with a new line character,
		// last line height has not been taken into account before
		if (!string_.isEmpty() && string_[string_.length() - 1] != '\n')
			yAdvance_ += font_->base();

		lineLengths_.pushBack(xAdvance_);
		if (xAdvance_ > xAdvanceMax)
			xAdvanceMax = xAdvance_;

		xAdvanceSum_ = xAdvanceMax;
		yAdvanceSum_ = yAdvance_;

		dirtyBoundaries_ = false;
	}
}

float TextNode::calculateAlignment(unsigned int lineIndex) const
{
	float alignOffset = 0.0f;

	switch (alignment_)
	{
		case Alignment::LEFT:
			alignOffset = 0.0f;
			break;
		case Alignment::CENTER:
			alignOffset = (xAdvanceSum_ - lineLengths_[lineIndex]) * 0.5f;
			break;
		case Alignment::RIGHT:
			alignOffset = xAdvanceSum_ - lineLengths_[lineIndex];
			break;
	}

	return alignOffset;
}

void TextNode::processGlyph(const FontGlyph *glyph, Degenerate degen)
{
	const Vector2i size = glyph->size();
	const Vector2i offset = glyph->offset();

	const float leftPos = xAdvance_ + offset.x;
	const float rightPos = leftPos + size.x;
	const float topPos = -yAdvance_ - offset.y;
	const float bottomPos = topPos - size.y;

	const Vector2i texSize = font_->texture()->size();
	const Recti texRect = glyph->texRect();

	const float leftCoord = float(texRect.x) / float(texSize.x);
	const float rightCoord = float(texRect.x + texRect.w) / float(texSize.x);
	const float bottomCoord = float(texRect.y + texRect.h) / float(texSize.y);
	const float topCoord = float(texRect.y) / float(texSize.y);

	if (degen == Degenerate::START || degen == Degenerate::START_END)
		interleavedVertices_.pushBack(Vertex(leftPos, bottomPos, leftCoord, bottomCoord));

	interleavedVertices_.pushBack(Vertex(leftPos, bottomPos, leftCoord, bottomCoord));
	interleavedVertices_.pushBack(Vertex(leftPos, topPos, leftCoord, topCoord));
	interleavedVertices_.pushBack(Vertex(rightPos, bottomPos, rightCoord, bottomCoord));
	interleavedVertices_.pushBack(Vertex(rightPos, topPos, rightCoord, topCoord));

	if (degen == Degenerate::START_END || degen == Degenerate::END)
		interleavedVertices_.pushBack(Vertex(rightPos, topPos, rightCoord, topCoord));

	xAdvance_ += glyph->xAdvance();
}

void TextNode::updateRenderCommand()
{
	renderCommand_->transformation() = worldMatrix_;
	textnodeBlock_->uniform("color")->setFloatVector(Colorf(absColor()).data());
}

}
