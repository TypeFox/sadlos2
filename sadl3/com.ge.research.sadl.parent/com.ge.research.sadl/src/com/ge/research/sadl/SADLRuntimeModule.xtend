/*
 * generated by Xtext 2.9.0-SNAPSHOT
 */
package com.ge.research.sadl

import com.ge.research.sadl.scoping.QualifiedNameConverter
import com.ge.research.sadl.scoping.QualifiedNameProvider
import com.ge.research.sadl.validation.SoftLinkingMessageProvider
import org.eclipse.xtext.linking.impl.LinkingDiagnosticMessageProvider
import org.eclipse.xtext.naming.IQualifiedNameConverter
import org.eclipse.xtext.validation.ResourceValidatorImpl
import com.ge.research.sadl.validation.ResourceValidator
import org.eclipse.xtext.generator.IOutputConfigurationProvider
import com.ge.research.sadl.generator.SADLOutputConfigurationProvider
import com.google.inject.Binder
import com.google.inject.Singleton

/**
 * Use this class to register components to be used at runtime / without the Equinox extension registry.
 */
class SADLRuntimeModule extends AbstractSADLRuntimeModule {
	
	override bindIQualifiedNameProvider() {
		QualifiedNameProvider
	}
	
	override configure (Binder binder)
	{
		super.configure(binder);
		binder.bind(IOutputConfigurationProvider).to(SADLOutputConfigurationProvider).in(Singleton);
	}
	
	def Class<? extends IQualifiedNameConverter> bindIQualifiedNameCoverter() {
		QualifiedNameConverter
	}
	
	def Class<? extends LinkingDiagnosticMessageProvider> bindILinkingDiagnosticMessageProvider() {
		SoftLinkingMessageProvider
	}
	
	override bindIValueConverterService() {
		ValueConverterService
	}
	
	def Class<? extends ResourceValidatorImpl> bindResourceValidatorImpl() {
		return ResourceValidator
	}
	
}
