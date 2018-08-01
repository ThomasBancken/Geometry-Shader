//************
// VARIABLES *
//************
cbuffer cbPerObject
{
	float4x4 m_MatrixWorldViewProj : WORLDVIEWPROJECTION;
	float4x4 m_MatrixWorld : WORLD;
	float3 m_LightDir = { 0.2f,-1.0f,0.2f };
}

RasterizerState FrontCulling
{
	CullMode = NONE;
};

DepthStencilState EnableDepth
{
	DepthEnable = TRUE;
	DepthWriteMask = ALL;
};


SamplerState samLinear
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;// of Mirror of Clamp of Border
	AddressV = Wrap;// of Mirror of Clamp of Border
};

//**********
// STRUCTS *
//**********
struct VS_DATA
{
	float3 Position : POSITION;
	float3 Normal : NORMAL;
	float3 BiNormal : BINORMAL;
	float3 Tangent : TANGENT;
	float2 TexCoord : TEXCOORD;
};

struct GS_DATA
{
	float4 Position : SV_POSITION;
	float3 Normal : NORMAL;
	float3 BiNormal : BINORMAL;
	float2 TexCoord : TEXCOORD0;
};

Texture2D m_TextureDiffuse;
float gSize;
int gFractalAmount;

static const float PI = 3.14159265f;

//****************
// VERTEX SHADER *
//****************
VS_DATA MainVS(VS_DATA vsData)
{
	return vsData;
}

//******************
// GEOMETRY SHADER *
//******************
float AngleBetween(float3 from, float3 to) //DEGREES
{
	float dotP = dot(from, to);
	float magFrom = sqrt((from.x * from.x) + (from.y * from.y) + from.z * from.z);
	float magTo = sqrt((to.x * to.x) + (to.y * to.y) + to.z * to.z);

	return acos(dotP / (magFrom * magTo));
}

float3 RotatePointAboutLine(float3 p, float angle, float3 p1, float3 p2)
{
	float3 u, q1, q2;
	float d;

	q1.x = p.x - p1.x;
	q1.y = p.y - p1.y;
	q1.z = p.z - p1.z;

	u.x = p2.x - p1.x;
	u.y = p2.y - p1.y;
	u.z = p2.z - p1.z;
	normalize(u);
	d = sqrt(u.y*u.y + u.z*u.z);

	if (d != 0) {
		q2.x = q1.x;
		q2.y = q1.y * u.z / d - q1.z * u.y / d;
		q2.z = q1.y * u.y / d + q1.z * u.z / d;
	}
	else {
		q2 = q1;
	}

	q1.x = q2.x * d - q2.z * u.x;
	q1.y = q2.y;
	q1.z = q2.x * u.x + q2.z * d;

	q2.x = q1.x * cos(angle) - q1.y * sin(angle);
	q2.y = q1.x * sin(angle) + q1.y * cos(angle);
	q2.z = q1.z;

	q1.x = q2.x * d + q2.z * u.x;
	q1.y = q2.y;
	q1.z = -q2.x * u.x + q2.z * d;

	if (d != 0) {
		q2.x = q1.x;
		q2.y = q1.y * u.z / d + q1.z * u.y / d;
		q2.z = -q1.y * u.y / d + q1.z * u.z / d;
	}
	else {
		q2 = q1;
	}

	q1.x = q2.x + p1.x;
	q1.y = q2.y + p1.y;
	q1.z = q2.z + p1.z;
	return(q1);
}

void CreateVertex(inout TriangleStream<GS_DATA> triStream, float3 pos, float3 normal, float2 texCoord)
{
	GS_DATA gsData = (GS_DATA)0;

	gsData.Position = mul(float4(pos, 1), m_MatrixWorldViewProj);

	gsData.Normal = mul(normal, (float3x3)m_MatrixWorld);

	gsData.TexCoord = texCoord;

	triStream.Append(gsData);
}

void CreateTopQuad(inout TriangleStream<GS_DATA> triStream, float3 posArr[19], float3 normArr[19], float sizeArr[19])
{
	for (int i = 0; i < gFractalAmount; ++i)
	{
		float halfSize = sizeArr[i] / 2;

		float3 leftTop, leftBottom, rightTop, rightBottom, normal;

		normal = normArr[i];

		float dotX = abs(dot(normal, float3(1, 0, 0)));
		float dotY = abs(dot(normal, float3(0, 1, 0)));
		float dotZ = abs(dot(normal, float3(0, 0, 1)));

		float3 rotVec = float3(0, 0, 1);

		if (dotX < dotY && dotX < dotZ)
		{
			rotVec = float3(1, 0, 0);
		}
		else if (dotY < dotX && dotY < dotZ)
		{
			rotVec = float3(0, 1, 0);
		}
		else
		{
			rotVec = float3(0, 0, 1);
		}

		float3 crossP = cross(rotVec, normal);
		float3 crossNorm = float3(crossP.x, crossP.y, crossP.z);

		leftTop		= (float3(0, 1, 0) * halfSize) + (float3(-1, 0, 0) * halfSize) + (float3(0, 0, 1)  * halfSize);
		leftBottom	= (float3(0, 1, 0) * halfSize) + (float3(-1, 0, 0) * halfSize) + (float3(0, 0, -1) * halfSize);
		rightTop	= (float3(0, 1, 0) * halfSize) + (float3(1, 0, 0)  * halfSize) + (float3(0, 0, 1)  * halfSize);
		rightBottom = (float3(0, 1, 0) * halfSize) + (float3(1, 0, 0)  * halfSize) + (float3(0, 0, -1) * halfSize);

		leftTop		= RotatePointAboutLine(leftTop,		AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		leftBottom	= RotatePointAboutLine(leftBottom,	AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightTop	= RotatePointAboutLine(rightTop,	AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightBottom = RotatePointAboutLine(rightBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);

		leftTop		+= posArr[i];
		leftBottom	+= posArr[i];
		rightTop	+= posArr[i];
		rightBottom += posArr[i];

		CreateVertex(triStream, leftTop, normal, float2(0, 0));
		CreateVertex(triStream, rightTop, normal, float2(1, 0));
		CreateVertex(triStream, leftBottom, normal, float2(0, 1));
		CreateVertex(triStream, rightBottom, normal, float2(1, 1));

		triStream.RestartStrip();
	}
}

[maxvertexcount(76)]
void TopQuad(point VS_DATA vertices[1], inout TriangleStream<GS_DATA> triStream)
{
	float3 basePoint, baseNormal, tempPoint, tempPoint2, tempNormal, biNormal, tangent;
	float size = gSize;
	float tempSize = size;

	float3 posArr[19];
	float3 normArr[19];
	float sizeArr[19];

	basePoint = vertices[0].Position;
	baseNormal = vertices[0].Normal;
	biNormal = vertices[0].BiNormal;
	tangent = vertices[0].Tangent;

	tempPoint = basePoint;
	tempNormal = baseNormal;

	//TOWER
	//gPositionsArr.push_back(basePoint);
	posArr[0] = basePoint;
	normArr[0] = baseNormal;
	sizeArr[0] = gSize;

	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[1] = tempPoint;
	normArr[1] = baseNormal;
	sizeArr[1] = size;

	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[6] = tempPoint;
	normArr[6] = baseNormal;
	sizeArr[6] = size;

	//SIDES1
	tempPoint = basePoint + (biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[2] = tempPoint;
	normArr[2] = baseNormal;
	sizeArr[2] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[15] = tempPoint2;
	normArr[15] = baseNormal;
	sizeArr[15] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[16] = tempPoint2;
	normArr[16] = baseNormal;
	sizeArr[16] = tempSize;

	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[11] = tempPoint;
	normArr[11] = baseNormal;
	sizeArr[11] = size;

	tempPoint = basePoint + (-biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[3] = tempPoint;
	normArr[3] = baseNormal;
	sizeArr[3] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[17] = tempPoint2;
	normArr[17] = baseNormal;
	sizeArr[17] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[18] = tempPoint2;
	normArr[18] = baseNormal;
	sizeArr[18] = tempSize;

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[12] = tempPoint;
	normArr[12] = baseNormal;
	sizeArr[12] = size;

	//SIDES2
	tempPoint = basePoint + (tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[4] = tempPoint;
	normArr[4] = baseNormal;
	sizeArr[4] = size;

	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[13] = tempPoint;
	normArr[13] = baseNormal;
	sizeArr[13] = size;

	tempPoint = basePoint + (-tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[5] = tempPoint;
	normArr[5] = baseNormal;
	sizeArr[5] = size;

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[14] = tempPoint;
	normArr[14] = baseNormal;
	sizeArr[14] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES3
	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[7] = tempPoint;
	normArr[7] = baseNormal;
	sizeArr[7] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[8] = tempPoint;
	normArr[8] = baseNormal;
	sizeArr[8] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES4
	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[9] = tempPoint;
	normArr[9] = baseNormal;
	sizeArr[9] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[10] = tempPoint;
	normArr[10] = baseNormal;
	sizeArr[10] = size;


	//TOP QUAD
	for (int i = 0; i < gFractalAmount; ++i)
	{
		CreateTopQuad(triStream, posArr, normArr, sizeArr);
	}
}

void CreateBotQuad(inout TriangleStream<GS_DATA> triStream, float3 posArr[19], float3 normArr[19], float sizeArr[19])
{
	for (int i = 0; i < gFractalAmount; ++i)
	{
		float halfSize = sizeArr[i] / 2;

		float3 leftTop, leftBottom, rightTop, rightBottom, normal;

		normal = normArr[i];

		float dotX = abs(dot(normal, float3(1, 0, 0)));
		float dotY = abs(dot(normal, float3(0, 1, 0)));
		float dotZ = abs(dot(normal, float3(0, 0, 1)));

		float3 rotVec = float3(0, 0, 1);

		if (dotX < dotY && dotX < dotZ)
		{
			rotVec = float3(1, 0, 0);
		}
		else if (dotY < dotX && dotY < dotZ)
		{
			rotVec = float3(0, 1, 0);
		}
		else
		{
			rotVec = float3(0, 0, 1);
		}

		float3 crossP = cross(rotVec, normal);
		float3 crossNorm = float3(crossP.x, crossP.y, crossP.z);

		leftTop = (float3(0, -1, 0) * halfSize) + (float3(-1, 0, 0) * halfSize) + (float3(0, 0, -1)  * halfSize);
		leftBottom = (float3(0, -1, 0) * halfSize) + (float3(-1, 0, 0) * halfSize) + (float3(0, 0, 1) * halfSize);
		rightTop = (float3(0, -1, 0) * halfSize) + (float3(1, 0, 0)  * halfSize) + (float3(0, 0, -1)  * halfSize);
		rightBottom = (float3(0, -1, 0) * halfSize) + (float3(1, 0, 0)  * halfSize) + (float3(0, 0, 1) * halfSize);

		leftTop = RotatePointAboutLine(leftTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		leftBottom = RotatePointAboutLine(leftBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightTop = RotatePointAboutLine(rightTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightBottom = RotatePointAboutLine(rightBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);

		leftTop += posArr[i];
		leftBottom += posArr[i];
		rightTop += posArr[i];
		rightBottom += posArr[i];

		CreateVertex(triStream, leftTop, normal, float2(0, 0));
		CreateVertex(triStream, rightTop, normal, float2(1, 0));
		CreateVertex(triStream, leftBottom, normal, float2(0, 1));
		CreateVertex(triStream, rightBottom, normal, float2(1, 1));

		triStream.RestartStrip();
	}
}

[maxvertexcount(76)]
void BotQuad(point VS_DATA vertices[1], inout TriangleStream<GS_DATA> triStream)
{
	float3 basePoint, baseNormal, tempPoint, tempPoint2, tempNormal, biNormal, tangent;
	float size = gSize;
	float tempSize = size;

	float3 posArr[19];
	float3 normArr[19];
	float sizeArr[19];

	basePoint = vertices[0].Position;
	baseNormal = vertices[0].Normal;
	biNormal = vertices[0].BiNormal;
	tangent = vertices[0].Tangent;

	tempPoint = basePoint;
	tempNormal = baseNormal;

	//TOWER
	//gPositionsArr.push_back(basePoint);
	posArr[0] = basePoint;
	normArr[0] = baseNormal;
	sizeArr[0] = gSize;

	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[1] = tempPoint;
	normArr[1] = baseNormal;
	sizeArr[1] = size;

	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[6] = tempPoint;
	normArr[6] = baseNormal;
	sizeArr[6] = size;

	//SIDES1
	tempPoint = basePoint + (biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[2] = tempPoint;
	normArr[2] = baseNormal;
	sizeArr[2] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[15] = tempPoint2;
	normArr[15] = baseNormal;
	sizeArr[15] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[16] = tempPoint2;
	normArr[16] = baseNormal;
	sizeArr[16] = tempSize;

	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[11] = tempPoint;
	normArr[11] = baseNormal;
	sizeArr[11] = size;

	tempPoint = basePoint + (-biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[3] = tempPoint;
	normArr[3] = baseNormal;
	sizeArr[3] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[17] = tempPoint2;
	normArr[17] = baseNormal;
	sizeArr[17] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[18] = tempPoint2;
	normArr[18] = baseNormal;
	sizeArr[18] = tempSize;

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[12] = tempPoint;
	normArr[12] = baseNormal;
	sizeArr[12] = size;

	//SIDES2
	tempPoint = basePoint + (tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[4] = tempPoint;
	normArr[4] = baseNormal;
	sizeArr[4] = size;

	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[13] = tempPoint;
	normArr[13] = baseNormal;
	sizeArr[13] = size;

	tempPoint = basePoint + (-tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[5] = tempPoint;
	normArr[5] = baseNormal;
	sizeArr[5] = size;

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[14] = tempPoint;
	normArr[14] = baseNormal;
	sizeArr[14] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES3
	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[7] = tempPoint;
	normArr[7] = baseNormal;
	sizeArr[7] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[8] = tempPoint;
	normArr[8] = baseNormal;
	sizeArr[8] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES4
	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[9] = tempPoint;
	normArr[9] = baseNormal;
	sizeArr[9] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[10] = tempPoint;
	normArr[10] = baseNormal;
	sizeArr[10] = size;

	//TOP QUAD
	for (int i = 0; i < gFractalAmount; ++i)
	{
		CreateBotQuad(triStream, posArr, normArr, sizeArr);
	}
}

void CreateLeftQuad(inout TriangleStream<GS_DATA> triStream, float3 posArr[19], float3 normArr[19], float sizeArr[19])
{
	for (int i = 0; i < gFractalAmount; ++i)
	{
		float halfSize = sizeArr[i] / 2;

		float3 leftTop, leftBottom, rightTop, rightBottom, normal;

		normal = normArr[i];

		float dotX = abs(dot(normal, float3(1, 0, 0)));
		float dotY = abs(dot(normal, float3(0, 1, 0)));
		float dotZ = abs(dot(normal, float3(0, 0, 1)));

		float3 rotVec = float3(0, 0, 1);

		if (dotX < dotY && dotX < dotZ)
		{
			rotVec = float3(1, 0, 0);
		}
		else if (dotY < dotX && dotY < dotZ)
		{
			rotVec = float3(0, 1, 0);
		}
		else
		{
			rotVec = float3(0, 0, 1);
		}

		float3 crossP = cross(rotVec, normal);
		float3 crossNorm = float3(crossP.x, crossP.y, crossP.z);

		leftTop = (float3(-1, 0, 0) * halfSize) + (float3(0, 1, 0)  * halfSize) + (float3(0, 0, 1)  * halfSize);
		leftBottom = (float3(-1, 0, 0) * halfSize) + (float3(0, -1, 0) * halfSize) + (float3(0, 0, 1)	* halfSize);
		rightTop = (float3(-1, 0, 0) * halfSize) + (float3(0, 1, 0)  * halfSize) + (float3(0, 0, -1) * halfSize);
		rightBottom = (float3(-1, 0, 0) * halfSize) + (float3(0, -1, 0) * halfSize) + (float3(0, 0, -1)	* halfSize);

		leftTop = RotatePointAboutLine(leftTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		leftBottom = RotatePointAboutLine(leftBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightTop = RotatePointAboutLine(rightTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightBottom = RotatePointAboutLine(rightBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);

		leftTop += posArr[i];
		leftBottom += posArr[i];
		rightTop += posArr[i];
		rightBottom += posArr[i];

		CreateVertex(triStream, leftTop, normal, float2(0, 0));
		CreateVertex(triStream, rightTop, normal, float2(1, 0));
		CreateVertex(triStream, leftBottom, normal, float2(0, 1));
		CreateVertex(triStream, rightBottom, normal, float2(1, 1));

		triStream.RestartStrip();
	}
}

[maxvertexcount(76)]
void LeftQuad(point VS_DATA vertices[1], inout TriangleStream<GS_DATA> triStream)
{
	float3 basePoint, baseNormal, tempPoint, tempPoint2, tempNormal, biNormal, tangent;
	float size = gSize;
	float tempSize = size;

	float3 posArr[19];
	float3 normArr[19];
	float sizeArr[19];

	basePoint = vertices[0].Position;
	baseNormal = vertices[0].Normal;
	biNormal = vertices[0].BiNormal;
	tangent = vertices[0].Tangent;

	tempPoint = basePoint;
	tempNormal = baseNormal;

	//TOWER
	//gPositionsArr.push_back(basePoint);
	posArr[0] = basePoint;
	normArr[0] = baseNormal;
	sizeArr[0] = gSize;

	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[1] = tempPoint;
	normArr[1] = baseNormal;
	sizeArr[1] = size;

	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[6] = tempPoint;
	normArr[6] = baseNormal;
	sizeArr[6] = size;

	//SIDES1
	tempPoint = basePoint + (biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[2] = tempPoint;
	normArr[2] = baseNormal;
	sizeArr[2] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[15] = tempPoint2;
	normArr[15] = baseNormal;
	sizeArr[15] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[16] = tempPoint2;
	normArr[16] = baseNormal;
	sizeArr[16] = tempSize;

	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[11] = tempPoint;
	normArr[11] = baseNormal;
	sizeArr[11] = size;

	tempPoint = basePoint + (-biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[3] = tempPoint;
	normArr[3] = baseNormal;
	sizeArr[3] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[17] = tempPoint2;
	normArr[17] = baseNormal;
	sizeArr[17] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[18] = tempPoint2;
	normArr[18] = baseNormal;
	sizeArr[18] = tempSize;

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[12] = tempPoint;
	normArr[12] = baseNormal;
	sizeArr[12] = size;

	//SIDES2
	tempPoint = basePoint + (tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[4] = tempPoint;
	normArr[4] = baseNormal;
	sizeArr[4] = size;

	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[13] = tempPoint;
	normArr[13] = baseNormal;
	sizeArr[13] = size;

	tempPoint = basePoint + (-tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[5] = tempPoint;
	normArr[5] = baseNormal;
	sizeArr[5] = size;

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[14] = tempPoint;
	normArr[14] = baseNormal;
	sizeArr[14] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES3
	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[7] = tempPoint;
	normArr[7] = baseNormal;
	sizeArr[7] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[8] = tempPoint;
	normArr[8] = baseNormal;
	sizeArr[8] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES4
	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[9] = tempPoint;
	normArr[9] = baseNormal;
	sizeArr[9] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[10] = tempPoint;
	normArr[10] = baseNormal;
	sizeArr[10] = size;


	//TOP QUAD
	for (int i = 0; i < gFractalAmount; ++i)
	{
		CreateLeftQuad(triStream, posArr, normArr, sizeArr);
	}
}

void CreateRightQuad(inout TriangleStream<GS_DATA> triStream, float3 posArr[19], float3 normArr[19], float sizeArr[19])
{
	for (int i = 0; i < gFractalAmount; ++i)
	{
		float halfSize = sizeArr[i] / 2;

		float3 leftTop, leftBottom, rightTop, rightBottom, normal;

		normal = normArr[i];

		float dotX = abs(dot(normal, float3(1, 0, 0)));
		float dotY = abs(dot(normal, float3(0, 1, 0)));
		float dotZ = abs(dot(normal, float3(0, 0, 1)));

		float3 rotVec = float3(0, 0, 1);

		if (dotX < dotY && dotX < dotZ)
		{
			rotVec = float3(1, 0, 0);
		}
		else if (dotY < dotX && dotY < dotZ)
		{
			rotVec = float3(0, 1, 0);
		}
		else
		{
			rotVec = float3(0, 0, 1);
		}

		float3 crossP = cross(rotVec, normal);
		float3 crossNorm = float3(crossP.x, crossP.y, crossP.z);

		leftTop = (float3(1, 0, 0) * halfSize) + (float3(0, 1, 0)  * halfSize) + (float3(0, 0, -1)  * halfSize);
		leftBottom = (float3(1, 0, 0) * halfSize) + (float3(0, -1, 0) * halfSize) + (float3(0, 0, -1)	* halfSize);
		rightTop = (float3(1, 0, 0) * halfSize) + (float3(0, 1, 0)  * halfSize) + (float3(0, 0, 1)   * halfSize);
		rightBottom = (float3(1, 0, 0) * halfSize) + (float3(0, -1, 0) * halfSize) + (float3(0, 0, 1)	* halfSize);

		leftTop = RotatePointAboutLine(leftTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		leftBottom = RotatePointAboutLine(leftBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightTop = RotatePointAboutLine(rightTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightBottom = RotatePointAboutLine(rightBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);

		leftTop += posArr[i];
		leftBottom += posArr[i];
		rightTop += posArr[i];
		rightBottom += posArr[i];

		CreateVertex(triStream, leftTop, normal, float2(0, 0));
		CreateVertex(triStream, rightTop, normal, float2(1, 0));
		CreateVertex(triStream, leftBottom, normal, float2(0, 1));
		CreateVertex(triStream, rightBottom, normal, float2(1, 1));

		triStream.RestartStrip();
	}
}

[maxvertexcount(76)]
void RightQuad(point VS_DATA vertices[1], inout TriangleStream<GS_DATA> triStream)
{
	float3 basePoint, baseNormal, tempPoint, tempPoint2, tempNormal, biNormal, tangent;
	float size = gSize;
	float tempSize = size;

	float3 posArr[19];
	float3 normArr[19];
	float sizeArr[19];

	basePoint = vertices[0].Position;
	baseNormal = vertices[0].Normal;
	biNormal = vertices[0].BiNormal;
	tangent = vertices[0].Tangent;

	tempPoint = basePoint;
	tempNormal = baseNormal;

	//TOWER
	//gPositionsArr.push_back(basePoint);
	posArr[0] = basePoint;
	normArr[0] = baseNormal;
	sizeArr[0] = gSize;

	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[1] = tempPoint;
	normArr[1] = baseNormal;
	sizeArr[1] = size;

	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[6] = tempPoint;
	normArr[6] = baseNormal;
	sizeArr[6] = size;

	//SIDES1
	tempPoint = basePoint + (biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[2] = tempPoint;
	normArr[2] = baseNormal;
	sizeArr[2] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[15] = tempPoint2;
	normArr[15] = baseNormal;
	sizeArr[15] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[16] = tempPoint2;
	normArr[16] = baseNormal;
	sizeArr[16] = tempSize;

	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[11] = tempPoint;
	normArr[11] = baseNormal;
	sizeArr[11] = size;

	tempPoint = basePoint + (-biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[3] = tempPoint;
	normArr[3] = baseNormal;
	sizeArr[3] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[17] = tempPoint2;
	normArr[17] = baseNormal;
	sizeArr[17] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[18] = tempPoint2;
	normArr[18] = baseNormal;
	sizeArr[18] = tempSize;

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[12] = tempPoint;
	normArr[12] = baseNormal;
	sizeArr[12] = size;

	//SIDES2
	tempPoint = basePoint + (tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[4] = tempPoint;
	normArr[4] = baseNormal;
	sizeArr[4] = size;

	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[13] = tempPoint;
	normArr[13] = baseNormal;
	sizeArr[13] = size;

	tempPoint = basePoint + (-tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[5] = tempPoint;
	normArr[5] = baseNormal;
	sizeArr[5] = size;

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[14] = tempPoint;
	normArr[14] = baseNormal;
	sizeArr[14] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES3
	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[7] = tempPoint;
	normArr[7] = baseNormal;
	sizeArr[7] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[8] = tempPoint;
	normArr[8] = baseNormal;
	sizeArr[8] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES4
	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[9] = tempPoint;
	normArr[9] = baseNormal;
	sizeArr[9] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[10] = tempPoint;
	normArr[10] = baseNormal;
	sizeArr[10] = size;


	//TOP QUAD
	for (int i = 0; i < gFractalAmount; ++i)
	{
		CreateRightQuad(triStream, posArr, normArr, sizeArr);
	}
}

void CreateFrontQuad(inout TriangleStream<GS_DATA> triStream, float3 posArr[19], float3 normArr[19], float sizeArr[19])
{
	for (int i = 0; i < gFractalAmount; ++i)
	{
		float halfSize = sizeArr[i] / 2;

		float3 leftTop, leftBottom, rightTop, rightBottom, normal;

		normal = normArr[i];

		float dotX = abs(dot(normal, float3(1, 0, 0)));
		float dotY = abs(dot(normal, float3(0, 1, 0)));
		float dotZ = abs(dot(normal, float3(0, 0, 1)));

		float3 rotVec = float3(0, 0, 1);

		if (dotX < dotY && dotX < dotZ)
		{
			rotVec = float3(1, 0, 0);
		}
		else if (dotY < dotX && dotY < dotZ)
		{
			rotVec = float3(0, 1, 0);
		}
		else
		{
			rotVec = float3(0, 0, 1);
		}

		float3 crossP = cross(rotVec, normal);
		float3 crossNorm = float3(crossP.x, crossP.y, crossP.z);

		leftTop = (float3(0, 0, -1) * halfSize) + (float3(0, 1, 0)  * halfSize) + (float3(1, 0, 0)  * halfSize);
		leftBottom = (float3(0, 0, -1) * halfSize) + (float3(0, -1, 0) * halfSize) + (float3(1, 0, 0)  * halfSize);
		rightTop = (float3(0, 0, -1) * halfSize) + (float3(0, 1, 0)  * halfSize) + (float3(-1, 0, 0) * halfSize);
		rightBottom = (float3(0, 0, -1) * halfSize) + (float3(0, -1, 0) * halfSize) + (float3(-1, 0, 0) * halfSize);

		leftTop = RotatePointAboutLine(leftTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		leftBottom = RotatePointAboutLine(leftBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightTop = RotatePointAboutLine(rightTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightBottom = RotatePointAboutLine(rightBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);

		leftTop += posArr[i];
		leftBottom += posArr[i];
		rightTop += posArr[i];
		rightBottom += posArr[i];

		CreateVertex(triStream, leftTop, normal, float2(0, 0));
		CreateVertex(triStream, rightTop, normal, float2(1, 0));
		CreateVertex(triStream, leftBottom, normal, float2(0, 1));
		CreateVertex(triStream, rightBottom, normal, float2(1, 1));

		triStream.RestartStrip();
	}
}

[maxvertexcount(76)]
void FrontQuad(point VS_DATA vertices[1], inout TriangleStream<GS_DATA> triStream)
{
	float3 basePoint, baseNormal, tempPoint, tempPoint2, tempNormal, biNormal, tangent;
	float size = gSize;
	float tempSize = size;

	float3 posArr[19];
	float3 normArr[19];
	float sizeArr[19];

	basePoint = vertices[0].Position;
	baseNormal = vertices[0].Normal;
	biNormal = vertices[0].BiNormal;
	tangent = vertices[0].Tangent;

	tempPoint = basePoint;
	tempNormal = baseNormal;

	//TOWER
	//gPositionsArr.push_back(basePoint);
	posArr[0] = basePoint;
	normArr[0] = baseNormal;
	sizeArr[0] = gSize;

	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[1] = tempPoint;
	normArr[1] = baseNormal;
	sizeArr[1] = size;

	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[6] = tempPoint;
	normArr[6] = baseNormal;
	sizeArr[6] = size;

	//SIDES1
	tempPoint = basePoint + (biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[2] = tempPoint;
	normArr[2] = baseNormal;
	sizeArr[2] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[15] = tempPoint2;
	normArr[15] = baseNormal;
	sizeArr[15] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[16] = tempPoint2;
	normArr[16] = baseNormal;
	sizeArr[16] = tempSize;

	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[11] = tempPoint;
	normArr[11] = baseNormal;
	sizeArr[11] = size;

	tempPoint = basePoint + (-biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[3] = tempPoint;
	normArr[3] = baseNormal;
	sizeArr[3] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[17] = tempPoint2;
	normArr[17] = baseNormal;
	sizeArr[17] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[18] = tempPoint2;
	normArr[18] = baseNormal;
	sizeArr[18] = tempSize;

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[12] = tempPoint;
	normArr[12] = baseNormal;
	sizeArr[12] = size;

	//SIDES2
	tempPoint = basePoint + (tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[4] = tempPoint;
	normArr[4] = baseNormal;
	sizeArr[4] = size;

	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[13] = tempPoint;
	normArr[13] = baseNormal;
	sizeArr[13] = size;

	tempPoint = basePoint + (-tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[5] = tempPoint;
	normArr[5] = baseNormal;
	sizeArr[5] = size;

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[14] = tempPoint;
	normArr[14] = baseNormal;
	sizeArr[14] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES3
	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[7] = tempPoint;
	normArr[7] = baseNormal;
	sizeArr[7] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[8] = tempPoint;
	normArr[8] = baseNormal;
	sizeArr[8] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES4
	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[9] = tempPoint;
	normArr[9] = baseNormal;
	sizeArr[9] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[10] = tempPoint;
	normArr[10] = baseNormal;
	sizeArr[10] = size;


	//TOP QUAD
	for (int i = 0; i < gFractalAmount; ++i)
	{
		CreateFrontQuad(triStream, posArr, normArr, sizeArr);
	}
}

void CreateBackQuad(inout TriangleStream<GS_DATA> triStream, float3 posArr[19], float3 normArr[19], float sizeArr[19])
{
	for (int i = 0; i < gFractalAmount; ++i)
	{
		float halfSize = sizeArr[i] / 2;

		float3 leftTop, leftBottom, rightTop, rightBottom, normal;

		normal = normArr[i];

		float dotX = abs(dot(normal, float3(1, 0, 0)));
		float dotY = abs(dot(normal, float3(0, 1, 0)));
		float dotZ = abs(dot(normal, float3(0, 0, 1)));

		float3 rotVec = float3(0, 0, 1);

		if (dotX < dotY && dotX < dotZ)
		{
			rotVec = float3(1, 0, 0);
		}
		else if (dotY < dotX && dotY < dotZ)
		{
			rotVec = float3(0, 1, 0);
		}
		else
		{
			rotVec = float3(0, 0, 1);
		}

		float3 crossP = cross(rotVec, normal);
		float3 crossNorm = float3(crossP.x, crossP.y, crossP.z);

		leftTop = (float3(0, 0, 1) * halfSize) + (float3(0, 1, 0)  * halfSize) + (float3(-1, 0, 0) * halfSize);
		leftBottom = (float3(0, 0, 1) * halfSize) + (float3(0, -1, 0) * halfSize) + (float3(-1, 0, 0) * halfSize);
		rightTop = (float3(0, 0, 1) * halfSize) + (float3(0, 1, 0)  * halfSize) + (float3(1, 0, 0)  * halfSize);
		rightBottom = (float3(0, 0, 1) * halfSize) + (float3(0, -1, 0) * halfSize) + (float3(1, 0, 0)	* halfSize);

		leftTop = RotatePointAboutLine(leftTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		leftBottom = RotatePointAboutLine(leftBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightTop = RotatePointAboutLine(rightTop, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);
		rightBottom = RotatePointAboutLine(rightBottom, AngleBetween(rotVec, normal), float3(0, 0, 0), crossNorm);

		leftTop += posArr[i];
		leftBottom += posArr[i];
		rightTop += posArr[i];
		rightBottom += posArr[i];

		CreateVertex(triStream, leftTop, normal, float2(0, 0));
		CreateVertex(triStream, rightTop, normal, float2(1, 0));
		CreateVertex(triStream, leftBottom, normal, float2(0, 1));
		CreateVertex(triStream, rightBottom, normal, float2(1, 1));

		triStream.RestartStrip();
	}
}

[maxvertexcount(76)]
void BackQuad(point VS_DATA vertices[1], inout TriangleStream<GS_DATA> triStream)
{
	float3 basePoint, baseNormal, tempPoint, tempPoint2, tempNormal, biNormal, tangent;
	float size = gSize;
	float tempSize = size;

	float3 posArr[19];
	float3 normArr[19];
	float sizeArr[19];

	basePoint = vertices[0].Position;
	baseNormal = vertices[0].Normal;
	biNormal = vertices[0].BiNormal;
	tangent = vertices[0].Tangent;

	tempPoint = basePoint;
	tempNormal = baseNormal;

	//TOWER
	//gPositionsArr.push_back(basePoint);
	posArr[0] = basePoint;
	normArr[0] = baseNormal;
	sizeArr[0] = gSize;

	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[1] = tempPoint;
	normArr[1] = baseNormal;
	sizeArr[1] = size;

	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[6] = tempPoint;
	normArr[6] = baseNormal;
	sizeArr[6] = size;

	//SIDES1
	tempPoint = basePoint + (biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[2] = tempPoint;
	normArr[2] = baseNormal;
	sizeArr[2] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[15] = tempPoint2;
	normArr[15] = baseNormal;
	sizeArr[15] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[16] = tempPoint2;
	normArr[16] = baseNormal;
	sizeArr[16] = tempSize;

	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[11] = tempPoint;
	normArr[11] = baseNormal;
	sizeArr[11] = size;

	tempPoint = basePoint + (-biNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[3] = tempPoint;
	normArr[3] = baseNormal;
	sizeArr[3] = size;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[17] = tempPoint2;
	normArr[17] = baseNormal;
	sizeArr[17] = tempSize;

	tempPoint2 = tempPoint;
	tempSize = size;

	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));
	tempSize = tempSize * 0.7f;
	tempPoint2 = tempPoint2 + (-tangent * (tempSize / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[18] = tempPoint2;
	normArr[18] = baseNormal;
	sizeArr[18] = tempSize;

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[12] = tempPoint;
	normArr[12] = baseNormal;
	sizeArr[12] = size;

	//SIDES2
	tempPoint = basePoint + (tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[4] = tempPoint;
	normArr[4] = baseNormal;
	sizeArr[4] = size;

	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[13] = tempPoint;
	normArr[13] = baseNormal;
	sizeArr[13] = size;

	tempPoint = basePoint + (-tangent * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[5] = tempPoint;
	normArr[5] = baseNormal;
	sizeArr[5] = size;

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[14] = tempPoint;
	normArr[14] = baseNormal;
	sizeArr[14] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES3
	tempPoint = tempPoint + (biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[7] = tempPoint;
	normArr[7] = baseNormal;
	sizeArr[7] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-biNormal * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-biNormal * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[8] = tempPoint;
	normArr[8] = baseNormal;
	sizeArr[8] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	//SIDES4
	tempPoint = tempPoint + (tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[9] = tempPoint;
	normArr[9] = baseNormal;
	sizeArr[9] = size;

	//INTERMEDIATE JUMP
	tempPoint = basePoint + (baseNormal * (gSize / 2.0f));
	size = gSize * 0.7f;
	tempPoint = tempPoint + (baseNormal * (size / 2.0f));
	//

	tempPoint = tempPoint + (-tangent * (size / 2.0f));
	size = size * 0.7f;
	tempPoint = tempPoint + (-tangent * (size / 2.0f));

	//gPositionsArr.push_back(tempPoint);
	posArr[10] = tempPoint;
	normArr[10] = baseNormal;
	sizeArr[10] = size;

	//TOP QUAD
	for (int i = 0; i < gFractalAmount; ++i)
	{
		CreateBackQuad(triStream, posArr, normArr, sizeArr);
	}
}

[maxvertexcount(3)]
void OriginalGeom(triangle VS_DATA vertices[3], inout TriangleStream<GS_DATA> triStream)
{
	//CreateVertex(triStream, vertices[0].Position, vertices[0].Normal, vertices[0].TexCoord);
	//CreateVertex(triStream, vertices[1].Position, vertices[1].Normal, vertices[1].TexCoord);
	//CreateVertex(triStream, vertices[2].Position, vertices[2].Normal, vertices[2].TexCoord);

	CreateVertex(triStream, vertices[0].Position, vertices[0].Normal, float2(0.1, 0.1));
	CreateVertex(triStream, vertices[1].Position, vertices[1].Normal, float2(0.1, 0.1));
	CreateVertex(triStream, vertices[2].Position, vertices[2].Normal, float2(0.1, 0.1));

	triStream.RestartStrip();
}

//***************
// PIXEL SHADER *
//***************
float4 MainPS(GS_DATA input) : SV_TARGET
{
	input.Normal = -normalize(input.Normal);
float alpha = m_TextureDiffuse.Sample(samLinear,input.TexCoord).a;
float3 color = m_TextureDiffuse.Sample(samLinear,input.TexCoord).rgb;
float s = max(dot(m_LightDir,input.Normal), 0.4f);

return float4(color*s,alpha);
}

//*************
// TECHNIQUES *
//*************
technique10 DefaultTechnique
{
	pass OriginalGeom
	{
		SetDepthStencilState(EnableDepth, 0);
		SetRasterizerState(FrontCulling);
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, OriginalGeom()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
	pass p0
	{
		SetDepthStencilState(EnableDepth, 0);
		SetRasterizerState(FrontCulling);
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, TopQuad()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
	pass p1
	{
		SetDepthStencilState(EnableDepth, 0);
		SetRasterizerState(FrontCulling);
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, BotQuad()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
	pass p2
	{
		SetDepthStencilState(EnableDepth, 0);
		SetRasterizerState(FrontCulling);
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, LeftQuad()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
	pass p3
	{
		SetDepthStencilState(EnableDepth, 0);
		SetRasterizerState(FrontCulling);
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, RightQuad()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
	pass p4
	{
		SetDepthStencilState(EnableDepth, 0);
		SetRasterizerState(FrontCulling);
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, FrontQuad()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
	pass p5
	{
		SetDepthStencilState(EnableDepth, 0);
		SetRasterizerState(FrontCulling);
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, BackQuad()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
}