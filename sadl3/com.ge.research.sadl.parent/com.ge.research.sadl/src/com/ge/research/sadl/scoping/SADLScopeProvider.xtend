/*
 * generated by Xtext 2.9.0-SNAPSHOT
 */
package com.ge.research.sadl.scoping

import com.ge.research.sadl.model.DeclarationExtensions
import com.ge.research.sadl.sADL.SADLPackage
import com.ge.research.sadl.sADL.SadlImport
import com.ge.research.sadl.sADL.SadlResource
import com.google.inject.Inject
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.impl.AbstractGlobalScopeDelegatingScopeProvider
import org.eclipse.xtext.scoping.impl.ImportNormalizer
import org.eclipse.xtext.scoping.impl.ImportScope
import org.eclipse.xtext.scoping.impl.MapBasedScope
import org.eclipse.xtext.scoping.impl.ScopeBasedSelectable

/**
 * This class contains custom scoping description.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#scoping
 * on how and when to use it.
 */
class SADLScopeProvider extends AbstractGlobalScopeDelegatingScopeProvider {

	@Inject extension DeclarationExtensions
	@Inject IQualifiedNameProvider qnProvider

	override getScope(EObject context, EReference reference) {
		// resolving imports against external models goes directly to the global scope
		if (reference.EReferenceType === SADLPackage.Literals.SADL_MODEL) {
			return super.getGlobalScope(context.eResource, reference)
		}
		if (SADLPackage.Literals.SADL_RESOURCE.isSuperTypeOf(reference.EReferenceType)) {
			return getSadlResourceScope(context, reference)
		}
		throw new UnsupportedOperationException(
			"Couldn't build scope for elements of type " + reference.EReferenceType.name)
	}

	protected def IScope getSadlResourceScope(EObject context, EReference reference) {
		val result = newHashMap
		val iter = context.eResource.allContents
		
		val IScope parent = createImportScope(context, reference)
		
		while (iter.hasNext) {
			switch it : iter.next {
				SadlResource case concreteName !== null: {
					val simpleName = QualifiedName.create(concreteName)
					result.addElement(simpleName, it)
					val qn = qnProvider.getFullyQualifiedName(it)
					result.addElement(qn, it)
				}
				SadlImport: {
				}
			}
		}
		return MapBasedScope.createScope(IScope.NULLSCOPE, result.values)
	}
	
	def IScope createImportScope(EObject object, EReference reference) {
		val imports = object.eResource.contents.head.eContents.filter(SadlImport).toList.reverseView
		var result = IScope.NULLSCOPE
		for (imp : imports) {
			val externalResource = imp.importedResource
			val alias = imp.alias ?: externalResource.alias
			//TODO support alias
			val uri = externalResource.baseUri
			val importNormalizer = new ImportNormalizer(QualifiedName.create(uri), true, false)
			result = new ImportScope(#[importNormalizer],result, new ScopeBasedSelectable(result), reference.EReferenceType, false)
		}
		return result
	}

	private def void addElement(Map<QualifiedName, IEObjectDescription> scope, QualifiedName qn, EObject obj) {
		if (!scope.containsKey(qn)) {
			scope.put(qn, new EObjectDescription(qn, obj, emptyMap))
		}
	}

}
